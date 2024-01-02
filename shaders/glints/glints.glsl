/**
 * Implementation of the realtime glitter approximation from
 * Deliot, T., and L. Belcour. "Real-Time Rendering of Glinty Appearances using Distributed Binomial Laws on Anisotropic Grids." (2023)
 * in GLSL
 */
#include "shared/debug.glsl"
#include "glints/math.glsl"
#include "glints/binom.glsl"
#include "glints/footprint.glsl"
#include "glints/hepta.glsl"
#include "glints/random.glsl"
#include "glints/tetra.glsl"
#line 14 205

// TODO: Integrate half vector to make glints pop in and out when rotating the light
float sampleFootprint(uint seed, float area, float weight, vec2 uv, float targetD, float p) {
    // Triangulate uv coordinates
    // TODO: Skew the triangulation for symmetric glint shapes
    const mat2 gridToSkewedGrid = mat2(1.0, -0.57735027, 0.0, 1.15470054);
    uv = gridToSkewedGrid * uv;
    vec2 cell = floor(uv);
    vec2 fractional = uv - cell;
    bool triangle = (fractional.x + fractional.y) > 1.0;
    vec2 a = triangle ? cell + vec2(1.0, 1.0) : cell;
    vec2 b = cell + vec2(1.0, 0.0);
    vec2 c = cell + vec2(0.0, 1.0);
    vec3 weights = calcBarycentrics(uv, a, b, c);
    GDEBUG_uvTriangles(weights);

    // Draw random numbers per triangle vertex
    vec3 randA = hash3f(uvec3(mapu(a), seed));
    vec3 randB = hash3f(uvec3(mapu(b), seed));
    vec3 randC = hash3f(uvec3(mapu(c), seed));

    // Randomize the logarithmic microfacet density
    vec3 logDensityRand = clamp(sampleNormal(uLogMicrofacetDensity, uDensityRandomization, vec3(randA.x, randB.x, randC.x)), 0.0, 50.0);
    vec3 density = exp(logDensityRand);
    // NP is the number of discrete microfacets in the weighted pixel footprint
    vec3 NP = area * density * weight; 

    vec3 samples;
    samples.x = sampleBinom(NP.x, p, randA.yz) / NP.x;
    samples.y = sampleBinom(NP.y, p, randB.yz) / NP.y;
    samples.z = sampleBinom(NP.z, p, randC.yz) / NP.z;

    return dot(samples, weights);
}

float sampleGridPoint(uint seed, vec3 gridPoint, float weight, vec2 uv, float targetD, float p) {
    // The area of the fotprint represented by the gridPoint is anisotropy * minorLength^2
    float area = gridPoint.y * gridPoint.z * gridPoint.z;

    GDEBUG_uvGrid(checkerboard(uv, 100.0));

    // FIXME: The transformation is off (theta seems to be wrong)
    // Transform the uv coordinate to be homogenous
    float theta = gridPoint.x;
    uv = vec2(cos(theta) * uv.x + sin(theta) * uv.y,
		      cos(theta) * uv.y - sin(theta) * uv.x); // Compensate for orientation
    uv.y /= gridPoint.y;  // Compensate for anisotropy
    uv /= gridPoint.z;    // Compensate for level of detail

    GDEBUG_uvGridCompensated(checkerboard(uv));

    return sampleFootprint(seed, area, weight, uv, targetD, p);
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

    GDEBUG_theta(angleToRGB(foot.angle));
    GDEBUG_aniso(vec3(1.0 / foot.ratio));
    GDEBUG_area(vec3(foot.area) * 4000.0);
    GDEBUG_major(normalToRGB(normalize(foot.major)));

    // The footprint can now be parametrized into three dimensions which are
    // logarithmic area (or LOD) + major/minor ratio (or anisotropy) + orientation
    // We define a grid on each of these dimensions to obtain a 3D Heptahedron that contains the footprint
    Heptahedron hepta = heptifyFootprint(foot);

    // The center case is the case without anisotropy
    // Then the orientation becomes irrelevant and the heptahedron collapses to a hexahedron
    bool centerCase = (hepta.aniso0 == 1.0);
    // In the center case we limit the theta weight by the anisotropy to account for the vanishing orientation dimension
    hepta.thetaWeight = centerCase ? hepta.thetaWeight * hepta.anisoWeight : hepta.thetaWeight;

    GDEBUG_grid(vec3(hepta.lod0 * 1000.0, 1.0 / hepta.aniso0, hepta.theta0 / DEG180));
    GDEBUG_thetaWeight(colorDebug(hepta.thetaWeight));
    GDEBUG_anisoWeight(colorDebug(hepta.anisoWeight));
    GDEBUG_lodWeight(colorDebug(hepta.lodWeight));
    GDEBUG_centerCase(boolToRGB(centerCase));

    // FIXME: The barycentric weights contain negative values
    // A is negative outside the center case
    // B, C and D are negative inside the center case
    Tetrahedron tetra = tetrifyFootprint(hepta, foot, centerCase);

    GDEBUG_baryA(colorDebug(tetra.weights.x));
	GDEBUG_baryB(colorDebug(tetra.weights.y));
	GDEBUG_baryC(colorDebug(tetra.weights.z));
	GDEBUG_baryD(colorDebug(tetra.weights.w));
    
    uint gridSeedA = seed(mapu(tetra.p0));
    uint gridSeedB = seed(mapu(tetra.p1));
    uint gridSeedC = seed(mapu(tetra.p2));
    uint gridSeedD = seed(mapu(tetra.p3));

    GDEBUG_seedA(vec3(mapf(gridSeedA)));

    float p = microfacetRoughness * D / Dmax;
    
    float sampleA = sampleGridPoint(gridSeedA, tetra.p0, tetra.weights.x, uv, D, p);
    float sampleB = sampleGridPoint(gridSeedB, tetra.p1, tetra.weights.y, uv, D, p);
    float sampleC = sampleGridPoint(gridSeedC, tetra.p2, tetra.weights.z, uv, D, p);
    float sampleD = sampleGridPoint(gridSeedD, tetra.p3, tetra.weights.w, uv, D, p);

    return (sampleA + sampleB + sampleC + sampleD) * (Dmax / microfacetRoughness);
}