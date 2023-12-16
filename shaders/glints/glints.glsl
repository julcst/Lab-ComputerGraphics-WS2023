/**
 * Implementation of the realtime glitter approximation from
 * Deliot, T., and L. Belcour. "Real-Time Rendering of Glinty Appearances using Distributed Binomial Laws on Anisotropic Grids." (2023)
 * in GLSL
 */
#include "shared/debug.glsl"
#include "glints/barycentric.glsl"
#include "glints/binom.glsl"
#include "glints/footprint.glsl"
#include "glints/random.glsl"
#line 12 205

// TODO: Renaming and restructuring for better readability

#define DEG360 6.28319
#define DEG180 3.14159
#define DEG90 1.5708
#define DEG45 0.785398

float fmod(float x, float y) {
    return x - y * trunc(x / y);
}

float map01(float x, float x0, float x1) {
    return (x - x0) / (x1 - x0);
}

struct Heptahedron {
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
    // the ground shape of our heptahedron is a pentagon
    // on the ratio-orientation plane
    float theta0;
    float thetaH;
    float theta1;
    float thetaWeight;
};

Heptahedron heptifyFootprint(Footprint foot) {
    Heptahedron hepta;
    // Discretize LOD with logarithmic scale
    // ? Why use the minor length instead of the area
    float lod = log2(foot.minorLength);
    hepta.lod0 = exp2(floor(lod));
    hepta.lod1 = hepta.lod0 * 2.0;
    //hepta.lodWeight = fract(lod);
    hepta.lodWeight = map01(foot.minorLength, hepta.lod0, hepta.lod1);

    // Discretize anisotropy with logarithmic scale
    float aniso = log2(foot.ratio);
    hepta.aniso0 = exp2(floor(aniso));
    hepta.aniso1 = hepta.aniso0 * 2.0;
    hepta.anisoWeight = map01(foot.ratio, hepta.aniso0, hepta.aniso1);

    // Discretize orientation with adaptive grid
    // Map the angle to the range [0, 180]
    float theta = fmod(foot.angle, DEG180);
    // The adaptive grid size depends on the anisotropy
    float thetaGrid = DEG90 / max(hepta.aniso0, 2.0);
    hepta.theta0 = floor(theta / thetaGrid) * thetaGrid;
    hepta.thetaH = hepta.theta0 + thetaGrid * 0.5;
    hepta.theta1 = hepta.theta0 + thetaGrid;
    hepta.thetaWeight = map01(theta, hepta.theta0, hepta.theta1);

    return hepta;
}

/**
 * Conatins the four vertices of a tetrahedron in the (area, ratio, orientation) space
 * and the barycentric weights of the current pixel footprint inside the tetrahedron
 */
struct Tetrahedron {
    vec3 p0, p1, p2, p3;
    vec4 weights;
};

/**
 * Splits the heptahedron into six tetrahedra by first splitting it into three prisms along the ground pentagon shape
 * and then splitting each prism into two tetrahedra along the diagonal
 *
 * NOTE:  In difference to the reference implementation I do not return the points of the tetrahedron relative to the heptahedron but in absolute coordinates.
 *        This avoids the dynamic indexing process used in the reference implementation and may benefit performance.
 *        Dynamic indexing can be costly because it may require the use of pointers instead of registers.
 */
Tetrahedron getTetrahedron(Heptahedron hepta, bool centerCase) {
    Tetrahedron tetra;

    // TODO: Thoroughly understand cutting
    //////////////////// Center Case ////////////////////
    if (centerCase) {
        // The points of the hexahedron in the form vec3(theta, aniso, area)
        // Ground triangle (lod0)
        vec3 a = vec3(hepta.theta0, hepta.aniso1, hepta.lod0);
        vec3 b = vec3(hepta.theta0, hepta.aniso0, hepta.lod0);
        vec3 c = vec3(hepta.theta1, hepta.aniso1, hepta.lod0); // e in heptahedron
        // Top triangle (lod1)
        vec3 d = vec3(hepta.theta0, hepta.aniso1, hepta.lod1); // f in heptahedron
        vec3 e = vec3(hepta.theta0, hepta.aniso0, hepta.lod1); // g in heptahedron
        vec3 f = vec3(hepta.theta1, hepta.aniso1, hepta.lod1); // j in heptahedron

        // Upper pyramid acdef
        if (hepta.lodWeight > 1.0 - hepta.anisoWeight) {
            // Left-up tetrahedron aedf
			if (map01(hepta.lodWeight, 1.0 - hepta.anisoWeight, 1.0) > hepta.thetaWeight) {
				tetra.p0 = a; tetra.p1 = e; tetra.p2 = d; tetra.p3 = f;
            // Right-down tetrahedron feca
            } else {
				tetra.p0 = f; tetra.p1 = e; tetra.p2 = c; tetra.p3 = a;
			}
        // Lower tetrahedron bace
		} else {
			tetra.p0 = b; tetra.p1 = a; tetra.p2 = c; tetra.p3 = e;
		}
    //////////////////// Normal Case ////////////////////
    } else { 

        // The points of the hepathedron in the form vec3(theta, aniso, area)
        // Ground pentagon (lod0), triangularization: abc, bcd, cde
        vec3 a = vec3(hepta.theta0, hepta.aniso1, hepta.lod0);
        vec3 b = vec3(hepta.theta0, hepta.aniso0, hepta.lod0);
        vec3 c = vec3(hepta.thetaH, hepta.aniso1, hepta.lod0);
        vec3 d = vec3(hepta.theta1, hepta.aniso0, hepta.lod0);
        vec3 e = vec3(hepta.theta1, hepta.aniso1, hepta.lod0);
        // Top pentagon (lod1), triangularization: fgh, ghi, hij
        vec3 f = vec3(hepta.theta0, hepta.aniso1, hepta.lod1);
        vec3 g = vec3(hepta.theta0, hepta.aniso0, hepta.lod1);
        vec3 h = vec3(hepta.thetaH, hepta.aniso1, hepta.lod1);
        vec3 i = vec3(hepta.theta1, hepta.aniso0, hepta.lod1);
        vec3 j = vec3(hepta.theta1, hepta.aniso1, hepta.lod1);

        // Firstly cut the heptahedron up into three prisms: abcfgh, bcdghi, cdehij
        // Then cut these prisms into three tetrahedrons each
        // Prism abcfgh
        if (hepta.thetaWeight < 0.5 && hepta.thetaWeight * 2.0 < hepta.anisoWeight) {
            // Upper pyramid acfgh
            if (hepta.lodWeight > 1.0 - hepta.anisoWeight) {
                // Tetrahedron afhg
                if (map01(hepta.lodWeight, 1.0 - hepta.anisoWeight, 1.0) > map01(hepta.thetaWeight * 2.0, 0.0, hepta.anisoWeight)) {
                    tetra.p0 = a; tetra.p1 = f; tetra.p2 = h; tetra.p3 = g;
                // Tetrahedron cahg
                } else {
                    tetra.p0 = c; tetra.p1 = a; tetra.p2 = h; tetra.p3 = g;
                }
            // Tetrahedron bacg
            } else {
                tetra.p0 = b; tetra.p1 = a; tetra.p2 = c; tetra.p3 = g;
            }
        // Prism bcdghi
        } else if (1.0 - ((hepta.thetaWeight - 0.5) * 2.0) > hepta.anisoWeight) {
            // Lower pyramid bcdgi
            if (hepta.lodWeight < 1.0 - hepta.anisoWeight) {
                // Tetrahedron bgic
                if (map01(hepta.lodWeight, 0.0, 1.0 - hepta.anisoWeight) > map01(hepta.thetaWeight, 0.5 - (1.0 - hepta.anisoWeight) * 0.5, 0.5 + (1.0 - hepta.anisoWeight) * 0.5)) {
                    tetra.p0 = b; tetra.p1 = g; tetra.p2 = i; tetra.p3 = c;
                // Tetrahedron dbci
                } else {
                    tetra.p0 = d; tetra.p1 = b; tetra.p2 = c; tetra.p3 = i;
                }
            // Tetrahedron cghi
            } else {
                tetra.p0 = c; tetra.p1 = g; tetra.p2 = h; tetra.p3 = i;
            }
        // Prism cdehij
        } else {
            // Upper pyramid cehij
            if (hepta.lodWeight > 1.0 - hepta.anisoWeight) {
                // Tetrahedron cjhi
                if (map01(hepta.lodWeight, 1.0 - hepta.anisoWeight, 1.0) > map01(hepta.thetaWeight * 2.0, 1.0 - hepta.anisoWeight, 1.0)) {
                    tetra.p0 = c; tetra.p1 = j; tetra.p2 = h; tetra.p3 = i;
                // Tetrahedron eicj
                } else {
                    tetra.p0 = e; tetra.p1 = i; tetra.p2 = c; tetra.p3 = j;
                }
            // Tetrahedron deci
            } else {
                tetra.p0 = d; tetra.p1 = e; tetra.p2 = c; tetra.p3 = i;
            }
        }
    }
    return tetra;
}

Tetrahedron tetrifyFootprint(Heptahedron hepta, Footprint foot, bool centerCase) {
    Tetrahedron tetra = getTetrahedron(hepta, centerCase);
    vec3 p = vec3(fmod(foot.angle, DEG180), foot.ratio, foot.minorLength);
    tetra.weights = calcBarycentric(p, tetra.p0, tetra.p1, tetra.p2, tetra.p3);
    return tetra;
}

float sampleGridPoint(vec2 uv, uint seed, float area, float target, float weight, float p) {
    // Triangulate uv coordinates
    // TODO: Skew the triangulation to reduce artifacts
    vec2 cell = floor(uv);
    vec2 fractional = uv - cell;
    bool triangle = (fractional.x + fractional.y) > 1.0;
    vec2 a = triangle ? cell + vec2(1.0, 1.0) : cell;
    vec2 b = cell + vec2(1.0, 0.0);
    vec2 c = cell + vec2(0.0, 1.0);
    vec3 weights = calcBarycentric(uv, a, b, c);
    GDEBUG_uvGrid(vec3(weights));

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

    GDEBUG_area(vec3(foot.area) * 4000.0);
    GDEBUG_theta(angleToRGB(foot.angle));
    GDEBUG_aniso(vec3(1.0 / foot.ratio));
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
    GDEBUG_lodWeight(vec3(hepta.lodWeight));
    GDEBUG_anisoWeight(vec3(hepta.anisoWeight));
    GDEBUG_thetaWeight(vec3(abs(hepta.thetaWeight)));
    GDEBUG_centerCase(boolToRGB(centerCase));

    // FIXME: The barycentric weights contain far more zeros than in the reference implementation
    Tetrahedron tetra = tetrifyFootprint(hepta, foot, centerCase);

    GDEBUG_baryA(vec3(tetra.weights.x));
	GDEBUG_baryB(vec3(tetra.weights.y));
	GDEBUG_baryC(vec3(tetra.weights.z));
	GDEBUG_baryD(vec3(tetra.weights.w));
    
    uint gridSeedA = seed(mapu(tetra.p0));
    uint gridSeedB = seed(mapu(tetra.p1));
    uint gridSeedC = seed(mapu(tetra.p2));
    uint gridSeedD = seed(mapu(tetra.p3));

    GDEBUG_seedA(vec3(mapf(gridSeedA)));

    float area = foot.area;
    float p = microfacetRoughness * D / Dmax;

    // TODO: Rotate uv grid to align with the orientation of the footprint
    // TODO: Integrate slope
    float sampleA = sampleGridPoint(uv / vec2(1.0, tetra.p0.y) / tetra.p0.z, gridSeedA, tetra.p0.y * tetra.p0.z * tetra.p0.z, D, tetra.weights.x, p);
    float sampleB = sampleGridPoint(uv / vec2(1.0, tetra.p1.y) / tetra.p1.z, gridSeedB, tetra.p1.y * tetra.p1.z * tetra.p1.z, D, tetra.weights.y, p);
    float sampleC = sampleGridPoint(uv / vec2(1.0, tetra.p2.y) / tetra.p2.z, gridSeedC, tetra.p2.y * tetra.p2.z * tetra.p2.z, D, tetra.weights.z, p);
    float sampleD = sampleGridPoint(uv / vec2(1.0, tetra.p3.y) / tetra.p3.z, gridSeedD, tetra.p3.y * tetra.p3.z * tetra.p3.z, D, tetra.weights.w, p);

    return (sampleA + sampleB + sampleC + sampleD) * (Dmax / microfacetRoughness);
}