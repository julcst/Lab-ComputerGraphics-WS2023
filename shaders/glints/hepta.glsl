#include "glints/math.glsl"
#line 3 206

struct Heptahedron {
    // Dimension 1: Orientation
    // Here we also need to store the half angle because
    // the ground shape of our heptahedron is a pentagon
    // on the ratio-orientation plane
    float theta0;
    float thetaH;
    float theta1;
    float thetaWeight;
    // Dimension 2: Anisotropy
    float aniso0;
    float aniso1;
    float anisoWeight;
    // Dimension 3: Area
    float lod0;
    float lod1;
    float lodWeight;
};

Heptahedron heptifyFootprint(Footprint foot) {
    Heptahedron hepta;

    // Discretize orientation with adaptive grid
    // Map the angle to the range [0, 180]
    float theta = fmod(foot.angle, DEG180);
    // The adaptive grid size depends on the anisotropy
    float thetaGrid = DEG90 / max(hepta.aniso0, 2.0);
    hepta.theta0 = floor(theta / thetaGrid) * thetaGrid;
    hepta.thetaH = hepta.theta0 + thetaGrid * 0.5;
    hepta.theta1 = hepta.theta0 + thetaGrid;
    hepta.thetaWeight = map01(theta, hepta.theta0, hepta.theta1);

    // Discretize anisotropy with logarithmic scale
    float aniso = log2(foot.ratio);
    hepta.aniso0 = exp2(floor(aniso));
    hepta.aniso1 = hepta.aniso0 * 2.0;
    hepta.anisoWeight = map01(foot.ratio, hepta.aniso0, hepta.aniso1);

    // Discretize LOD with logarithmic scale
    // ? Why use the minor length instead of the area
    float lod = log2(foot.minorLength);
    hepta.lod0 = exp2(floor(lod));
    hepta.lod1 = hepta.lod0 * 2.0;
    //hepta.lodWeight = fract(lod);
    hepta.lodWeight = map01(foot.minorLength, hepta.lod0, hepta.lod1);

    return hepta;
}