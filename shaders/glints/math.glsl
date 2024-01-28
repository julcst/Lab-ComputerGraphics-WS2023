#line 2 201

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

/**
 * Grid values are in the format vec4(v00, v01, v10, v11)
 */
float bilinear(vec4 values, vec2 weights) {
    vec2 lerp = mix(values.xy, values.zw, weights.x);
    return mix(lerp.x, lerp.y, weights.y);
}

/**
 * Returns the length of the cross product of two vectors when we add a imaginative z-component of 0.
 * The result is thus the area of the parallelogram spanned by the two vectors or twice the area of the triangle spanned by the two vectors.
 */
float cross2D(vec2 a, vec2 b) {
    // = ||(ay*bz - az*by, az*bx - ax*bz, ax*by - ay*bx)||
    // = ||(ay*0  - 0*by,  0*bx  - ax*0,  ax*by - ay*bx)||
    // = ||(0,             0,             ax*by - ay*bx)||
    // = |ax*by - ay*bx|, but we keep the sign
    return a.x * b.y - a.y * b.x;
}

/**
 * Calculates the barycentric coordinates of a point p in a triangle (a, b, c) in 2D space.
 * The implementation is based on area ratios, the area of a triangle (a, b, c) is |cross(ab, ac)| / 2.
 * Because we are only interested in the ratios, we can omit the sign and the division by 2.
 */
vec3 calcBarycentrics(vec2 P, vec2 A, vec2 B, vec2 C) {
    vec2 AP = P - A;
    
    vec2 AB = B - A;
    vec2 AC = C - A;

    float areaABC = cross2D(AB, AC);
    float invAreaABC = 1.0 / areaABC; // To avoid divisions later

    float areaABP = cross2D(AB, AP);
    float areaACP = cross2D(AP, AC);

    vec3 weights;
    weights.z = areaABP * invAreaABC; // C
    weights.y = areaACP * invAreaABC; // B
    weights.x = 1.0 - weights.y - weights.z; // A - Because the weights sum up to 1.0

    return weights;
}

/**
 * Calculates the barycentric coordinates of a point p in a tetrahedron (a, b, c, d) in 3D space.
 * The implementation is based on volume ratios, the volume of a tetrahedron (a, b, c, d) is |dot(cross(ab, bc), ad)| / 6.
 * Because we are only interested in the ratios, we can omit the sign and the division by 6.
 * Calculation taken from appendix 4 of "Robust and Efficient Barycentric Cell-Interpolation for Volumetric Coupling with preCICE" by Boris G. Martin, 2022
 */
 vec4 calcBarycentrics(vec3 P, vec3 A, vec3 B, vec3 C, vec3 D) {
    vec3 AP = P - A;
    vec3 CP = P - C;
    vec3 DP = P - B;

    vec3 AB = B - A;
    vec3 AC = C - A;
    vec3 AD = D - A;
    vec3 BC = C - B;

    vec3 ABC = cross(AB, BC);
    vec3 ABD = cross(AB, -AD);
    vec3 ACD = cross(AC, AD);

    float volumeABCD = dot(ABC, AD);
    float invVolumeABCD = 1.0 / volumeABCD; // To avoid divisions later

    float volumeABCP = dot(ABC, AP);
    float volumeABDP = dot(ABD, DP);
    float volumeACDP = dot(ACD, CP);

    // Calculate the barycentric coordinates as the volume ratios
    vec4 weights;
    weights.w = volumeABCP * invVolumeABCD; // D
    weights.z = volumeABDP * invVolumeABCD; // C
    weights.y = volumeACDP * invVolumeABCD; // B
    weights.x = 1.0 - weights.y - weights.z - weights.w; // A - Because the weights sum up to 1.0

    return weights;
 }