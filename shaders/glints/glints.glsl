/**
 * Implementation of the realtime glitter approximation from
 * Deliot, T., and L. Belcour. "Real-Time Rendering of Glinty Appearances using Distributed Binomial Laws on Anisotropic Grids." (2023)
 * in GLSL
 */
#include "glints/binom.glsl"
#include "glints/footprint.glsl"
#include "glints/random.glsl"

#define DEBUG(i, v) if (uDebug == uint(i)) fragColor = v

#define DEG360 6.28319
#define DEG180 3.14159
#define DEG90 1.5708

float map01(float x, float x0, float x1) {
    return (x - x0) / (x1 - x0);
}

struct HeptaFootprint {
    // Dimension 1: Area
    float lod0;
    float lod1;
    float lodWeight;
    // Dimension 2: Ratio
    float aniso0;
    float aniso1;
    float anisoWeight;
    // Dimension 3: Orientation
    // Here we also need to store the half angle because
    // the ground shape of our heptaeder is a pentagon
    // on the ratio-orientation plane
    float theta0;
    float thetaH;
    float theta1;
    float thetaWeight;
};

HeptaFootprint heptifyFootprint(Footprint foot) {
    HeptaFootprint hepta;

    // Discretize LOD with logarithmic scale
    float lod = log2(foot.minorLength);
    hepta.lod0 = exp2(floor(lod));
    hepta.lod1 = hepta.lod0 * 2.0;
    hepta.lodWeight = map01(foot.minorLength, hepta.lod0, hepta.lod1);

    // Discretize anisotropy with logarithmic scale
    float aniso = log2(foot.ratio);
    hepta.aniso0 = exp2(floor(aniso));
    hepta.aniso1 = hepta.aniso0 * 2.0;
    hepta.anisoWeight = map01(foot.ratio, hepta.aniso0, hepta.aniso1);

    // Discretize orientation with adaptive grid
    float theta = foot.angle;
    float thetaGrid = DEG90 / max(hepta.aniso0, 2.0);
    float thetaBin = floor(theta / thetaGrid) * thetaGrid;
    hepta.theta0 = theta < thetaBin ? thetaBin : thetaBin + thetaGrid / 2.0;
	hepta.thetaH = hepta.theta0 + thetaGrid / 4.0;
	hepta.theta1 = hepta.theta0 + thetaGrid / 2.0;
    hepta.thetaWeight = map01(theta, hepta.theta0, hepta.theta1);
    hepta.theta0 = hepta.theta0 <= 0.0 ? hepta.theta0 + DEG180 : hepta.theta0;

DEBUG(10, vec3(hepta.lod0 * 1000.0, hepta.aniso0, hepta.theta0 / DEG360 + 0.5));
DEBUG(11, vec3(hepta.lodWeight));
DEBUG(12, vec3(hepta.anisoWeight));
DEBUG(13, vec3(hepta.thetaWeight));

    return hepta;
}

/**
 * Extenda a given distribution term D with a stochastic microfacet counting process to account
 * for the mesoscopic microfacet distribution inside the pixel footprint and simulate glinty appearance
 *
 * @param D The target normal distribution term
 * @param Dmax The maximum possible value for the distribution term (achieved at the shading normal)
 * @param uv The texture coordinates of the current fragment (derivatives are used to estimate the pixel footprint)
 * @param screenSpaceScale Used to scale the effect
 * @param microfacetRoughness 
 * @param logMicrofacetDenisty The mean density of microfacets in the pixel footprint
 * @param densityRandomization The deviation of the microfacet density in the pixel footprint
 *
 * @return The modified distribution term DP accounting for the mesoscopic microfacet distribution
 */
float D_glints(float D, float Dmax, vec2 uv, float screenSpaceScale, float microfacetRoughness, float logMicrofacetDensity, float densityRandomization) {
    // Calculate the pixel footprint
    Footprint foot = calcPixelFootprint(uv, screenSpaceScale);

    // The footprint can now be parametrized into three dimensions which are
    // logarithmic area (or LOD) + major/minor ratio (or anisotropy) + orientation
    // We define a grid on each of these dimensions to obtain a 3D Heptaeder that contains the footprint
    HeptaFootprint hepta = heptifyFootprint(foot);

    // TODO TetraFootprint tetraFoot = tetrifyFootprint(hepta);
    
    // Generate incoherent random numbers based on the uv coordinates
    vec3 rand = hash3f(vec3(uv.xy, uv.x * uv.y));

    // p ist the probability for a single microfacet to be reflecting
    float p = microfacetRoughness * D / Dmax;

    // Randomize the logarithmic microfacet density
    // ? Wouldn't it be more intuitive to randomize the linear microfacet density instead?
    // ? Why is this normal distributed and not binomial distributed
    float logDensityRand = clamp(sampleNormal(logMicrofacetDensity, densityRandomization, rand.x), 0.0, 50.0);
    // NP is the number of discrete microfacets in the pixel footprint
    float NP = foot.area * exp(logDensityRand);
    // c is the number of reflecting microfacets in the pixel footprint
    float c = (Dmax / uMicrofacetRoughness) * sampleBinom(NP, p, rand.yz); // Equation (4)
    // DP is the microfacet distribution term over the pixel footprint
    float DP = c / NP; // Equation (3)

    return DP;
}