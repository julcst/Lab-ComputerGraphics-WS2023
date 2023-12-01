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

struct HexaFootprint {
    // Dimension 1: Logarithmic area
    float lod0;
    float lod1;
    float lodWeight;
    // Dimension 2: Anisotropy
    float aniso0;
    float aniso1;
    float anisoWeight;
    // Dimension 3: Orientation
    float theta0;
    float thetaH;
    float theta1;
    float thetaWeight;
};

HexaFootprint hexifyFootprint(Footprint foot) {
    HexaFootprint hexaFoot;

    // Discretize LOD with logarithmic scale
    float lod = log2(foot.minorLength);
    hexaFoot.lod0 = exp2(floor(lod));
    hexaFoot.lod1 = hexaFoot.lod0 * 2.0;
    hexaFoot.lodWeight = map01(foot.minorLength, hexaFoot.lod0, hexaFoot.lod1);

    // Discretize anisotropy with logarithmic scale
    float aniso = log2(foot.ratio);
    hexaFoot.aniso0 = exp2(floor(aniso));
    hexaFoot.aniso1 = hexaFoot.aniso0 * 2.0;
    hexaFoot.anisoWeight = map01(foot.ratio, hexaFoot.aniso0, hexaFoot.aniso1);

    // Discretize orientation with adaptive grid
    float theta = foot.angle;
    float thetaGrid = DEG90 / max(hexaFoot.aniso0, 2.0);
    float thetaBin = floor(theta / thetaGrid) * thetaGrid;
    hexaFoot.theta0 = theta < thetaBin ? thetaBin : thetaBin + thetaGrid / 2.0;
	hexaFoot.thetaH = hexaFoot.theta0 + thetaGrid / 4.0;
	hexaFoot.theta1 = hexaFoot.theta0 + thetaGrid / 2.0;
    hexaFoot.thetaWeight = map01(theta, hexaFoot.theta0, hexaFoot.theta1);
    hexaFoot.theta0 = hexaFoot.theta0 <= 0.0 ? hexaFoot.theta0 + DEG180 : hexaFoot.theta0;

DEBUG(10, vec3(hexaFoot.lod0 * 1000.0, hexaFoot.aniso0, hexaFoot.theta0 / DEG360 + 0.5));
DEBUG(11, vec3(hexaFoot.lodWeight, hexaFoot.anisoWeight, hexaFoot.thetaWeight));

    return hexaFoot;
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
    // We define a grid in each on these dimensions to obtain a 3D Hexaeder that contains the footprint
    HexaFootprint hexaFoot = hexifyFootprint(foot);

    // TODO TetraFootprint tetraFoot = tetrifyFootprint(hexaFoot);
    
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