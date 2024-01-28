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

// ! This is executed 4*3=12 times per pixel (for each corner of the uv triangle of the vertex of the tetrahedron)
float sampleAngularBinom(float N, float pOneSuccess, float mu, float sigma, vec2 slope, vec2 rand) {
    // Randomize the slope
    vec2 randomizedSlope = slope + rand * 4096;

    // Now discretize the slope plane into a grid and calculate the bilinear weights
    uvec2 slopeCoord = uvec2(floor(randomizedSlope));
    vec2 slopeWeight = fract(randomizedSlope);

    // Draw 2 random numbers (A and B) per slope grid point
    vec4 randA = hash4f(uvec4(slopeCoord.xy, slopeCoord.yx + 4096U));
	vec4 randB = hash4f(uvec4(slopeCoord.yx + 8192U, slopeCoord.xy + 16384U));

    // Sample the binomial distribution per slope grid point and interpolate bilinearly
    // ! 4*3*4=48 binomial samples per pixel (once for each corner of the slope square per corner of the uv triangle of the vertex of the tetrahedron)
    float sample = bilinear(sampleBinom(N, pOneSuccess, mu, sigma, randA, randB), slopeWeight);
    return sample;
}

// ! This is executed 4 times per pixel (for each vertex of the tetrahedron)
float sampleFootprint(uint seed, float area, float weight, vec2 slope, vec2 uv, float targetD, float p) {
    // Skew the uv grid to make the hexagonal glint shapes symmetric
    const mat2 gridToSkewedGrid = mat2(1.0, -0.57735027, 0.0, 1.15470054);
    uv = gridToSkewedGrid * uv;

    // Triangulate uv coordinates
    vec2 cell = floor(uv);
    vec2 fractional = uv - cell;
    bool triangle = (fractional.x + fractional.y) > 1.0;
    // a, b and c are the vertices of the uv triangle
    vec2 a = triangle ? cell + vec2(1.0, 1.0) : cell;
    vec2 b = cell + vec2(1.0, 0.0);
    vec2 c = cell + vec2(0.0, 1.0);
    // weights are the barycentric coordinates of the uv coordinate in abc
    vec3 weights = calcBarycentrics(uv, a, b, c);

GDEBUG_uvTriangles(weights);

    // Draw random numbers per triangle vertex
    vec3 randA = hash3f(uvec3(mapu(a), seed));
    vec3 randB = hash3f(uvec3(mapu(b), seed));
    vec3 randC = hash3f(uvec3(mapu(c), seed));

    // Randomize the logarithmic microfacet density per vertex
    vec3 logDensityRand = clamp(sampleNormal(uLogMicrofacetDensity, uDensityRandomization, vec3(randA.x, randB.x, randC.x)), 0.0, 50.0);
    vec3 density = exp(logDensityRand);
    // NP is the number of discrete microfacets in the weighted pixel footprint per vertex
    vec3 NP = area * density * weight; // Multiply by weight (Distributed Binomial Law)

    // Calculate pOneSuccess, mu and sigma per vertex to make the binomial distibution sampling step faster
    // The probability of having at least one success in a binomial distribution b(N,p)
    vec3 pOneSuccess = 1.0 - pow(vec3(1.0 - p), NP); // Equation (16)
    // Compute the parameters of the normal approximation of the binomial distribution for one less sample, b(N-1,p)
    vec3 mu = (NP - 1.0) * p;
    vec3 sigma = sqrt((NP - 1.0) * p * (1.0 - p)); // Equation (17)

    // Sample the binomial distribution per vertex
    vec3 samples;
    samples.x = sampleAngularBinom(NP.x, pOneSuccess.x, mu.x, sigma.x, slope, randA.yz);
    samples.y = sampleAngularBinom(NP.y, pOneSuccess.y, mu.y, sigma.y, slope, randB.yz);
    samples.z = sampleAngularBinom(NP.z, pOneSuccess.z, mu.z, sigma.z, slope, randC.yz);
    samples /= NP; // Normalize the samples

    // Interpolate the samples using the barycentric coordinates (Distributed Binomial Law)
    return dot(samples, weights);
}

// ! This is executed 4 times per pixel (for each vertex of the tetrahedron)
float sampleGridPoint(uint seed, vec3 gridPoint, float weight, vec2 slope, vec2 uv, float targetD, float p) {
    // The area of the footprint represented by the gridPoint is anisotropy * minorLength^2
    float area = gridPoint.y * gridPoint.z * gridPoint.z;

    // Transform the uv coordinate to be homogenous
    // Do not rotate the uv coordinate if the gridPoint is in the center case (anisotropy == 1.0)
    float theta = gridPoint.y == 1.0 ? 0.0 : gridPoint.x;
    uv = vec2(cos(theta) * uv.x + sin(theta) * uv.y,
		      cos(theta) * uv.y - sin(theta) * uv.x); // Compensate for orientation
    uv.y /= gridPoint.y;  // Compensate for anisotropy
    uv /= gridPoint.z;    // Compensate for level of detail

    // The resulting uv grid now closely matches 1 texel per 1 pixel

GDEBUG_uvGridCompensated(checkerboard(uv, 0.5));

    // Now sample the footprint using the new compensated uv coordinate
    return sampleFootprint(seed, area, weight, slope, uv, targetD, p);
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
float D_glints(float D, float Dmax, vec3 H, vec2 uv, float screenSpaceScale, float microfacetRoughness, float logMicrofacetDensity, float densityRandomization) {
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

GDEBUG_grid(vec3(hepta.lod0 * 1000.0, 1.0 / hepta.aniso0, hepta.theta0 / DEG180));
GDEBUG_thetaWeight(colorDebug(hepta.thetaWeight));
GDEBUG_anisoWeight(colorDebug(hepta.anisoWeight));
GDEBUG_lodWeight(colorDebug(hepta.lodWeight));
GDEBUG_centerCase(boolToRGB(centerCase));

GDEBUG0(boolToRGB(hepta.theta0 <= foot.angle && foot.angle <= hepta.thetaH));
GDEBUG1(boolToRGB(hepta.thetaH <= foot.angle && foot.angle <= hepta.theta1));
GDEBUG2(boolToRGB(hepta.theta0 < hepta.thetaH && hepta.thetaH < hepta.theta1));

    // TODO: The barycentric weights contain negative values
    // A is negative outside the center case
    // B, C and D are negative inside the center case
    Tetrahedron tetra = tetrifyFootprint(hepta, foot, centerCase);

GDEBUG_baryA(colorDebug(tetra.weights.x));
GDEBUG_baryB(colorDebug(tetra.weights.y));
GDEBUG_baryC(colorDebug(tetra.weights.z));
GDEBUG_baryD(colorDebug(tetra.weights.w));

    // Draw random seeds per grid point
    uint gridSeedA = seed(mapu(tetra.p0));
    uint gridSeedB = seed(mapu(tetra.p1));
    uint gridSeedC = seed(mapu(tetra.p2));
    uint gridSeedD = seed(mapu(tetra.p3));

GDEBUG_seedA(vec3(mapf(gridSeedA)));

    // p is the probability of a microfacet being reflecting
    float p = microfacetRoughness * D / Dmax;

    // Project H onto the tangent plane
    vec2 slope = H.xy;
    // Make slope symmetric and compensate for microfacet roughness
    slope = abs(slope) / uMicrofacetRoughness;

GDEBUG_uvGrid(checkerboard(uv, 100.0));

    // Now sample the grid points
    float sampleA = sampleGridPoint(gridSeedA, tetra.p0, tetra.weights.x, slope, uv, D, p);
    float sampleB = sampleGridPoint(gridSeedB, tetra.p1, tetra.weights.y, slope, uv, D, p);
    float sampleC = sampleGridPoint(gridSeedC, tetra.p2, tetra.weights.z, slope, uv, D, p);
    float sampleD = sampleGridPoint(gridSeedD, tetra.p3, tetra.weights.w, slope, uv, D, p);

    // The samples are then weighted by the barycentric coordinates of the footprint so we can apply the Distributed Binomial Law
    return (sampleA + sampleB + sampleC + sampleD) * (Dmax / microfacetRoughness);
}