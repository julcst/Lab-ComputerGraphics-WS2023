#line 2 103
#if 1 // Enable or disable debug macros
#define RENDER_VIEW(c) if (uDebug == 0U) fragColor = c
#define DEBUG_VIEW(i, v) if (uDebug == uint(i)) fragColor = v
#else
#define RENDER_VIEW(c) fragColor = c
#define DEBUG_VIEW(i, v)
#endif

// Glints debug macros
#define GDEBUG_D(v) DEBUG_VIEW(1, v)
#define GDEBUG_Dmax(v) DEBUG_VIEW(2, v)
#define GDEBUG_DP(v) DEBUG_VIEW(3, v)
#define GDEBUG_area(v) DEBUG_VIEW(4, v)
#define GDEBUG_theta(v) DEBUG_VIEW(5, v)
#define GDEBUG_aniso(v) DEBUG_VIEW(6, v)
#define GDEBUG_lod(v) DEBUG_VIEW(7, v)
#define GDEBUG_grid(v) DEBUG_VIEW(8, v)
#define GDEBUG_lodWeight(v) DEBUG_VIEW(9, v)
#define GDEBUG_anisoWeight(v) DEBUG_VIEW(10, v)
#define GDEBUG_thetaWeight(v) DEBUG_VIEW(11, v)
#define GDEBUG_centerCase(v) DEBUG_VIEW(12, v)
#define GDEBUG_baryA(v) DEBUG_VIEW(13, v)
#define GDEBUG_baryB(v) DEBUG_VIEW(14, v)
#define GDEBUG_baryC(v) DEBUG_VIEW(15, v)
#define GDEBUG_baryD(v) DEBUG_VIEW(16, v)
#define GDEBUG_seedA(v) DEBUG_VIEW(17, v)
#define GDEBUG_uvGrid(v) DEBUG_VIEW(18, v)
#define GDEBUG_uvGridCompensated(v) DEBUG_VIEW(19, v)
#define GDEBUG_uvTriangles(v) DEBUG_VIEW(20, v)
#define GDEBUG_samples(v) DEBUG_VIEW(21, v)
#define GDEBUG_slopeLerp(v) DEBUG_VIEW(22, v)
#define GDEBUG_baryCheck2(v) DEBUG_VIEW(23, v)
#define GDEBUG_baryCheck3(v) DEBUG_VIEW(24, v)
#define GDEBUG0(v) DEBUG_VIEW(25, v)
#define GDEBUG1(v) DEBUG_VIEW(26, v)
#define GDEBUG2(v) DEBUG_VIEW(27, v)
#define GDEBUG_slope(v) DEBUG_VIEW(28, v)
#define GDEBUG_H(v) DEBUG_VIEW(29, v)

/**
 * Interprets angle as hue and converts it to RGB.
 */
vec3 angleToRGB(float angle) {
    float angle01 = angle / 6.283 + 0.5;
    return clamp(abs(mod(angle01 * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

vec3 checkerboard(vec2 uv) {
    vec2 p = floor(uv);
    return vec3(mod(p.x + p.y, 2.0));
}

vec3 checkerboard(vec2 uv, float steps) {
    vec2 p = floor(uv * steps);
    return vec3(mod(p.x + p.y, 2.0));
}

vec3 normalToRGB(vec3 normal) {
    return normal * 0.5 + 0.5;
}

vec3 normalToRGB(vec2 normal) {
    return vec3(normal * 0.5 + 0.5, 0.0);
}

vec3 boolToRGB(bool b) {
    return b ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
}

vec3 colorDebug(float x) {
    if (isnan(x)) return vec3(1.0, 0.0, 1.0);
    if (isinf(x)) return vec3(1.0, 0.0, 0.0);
    if (x <  0.0) return vec3(0.0, 0.0, 1.0);
    if (x >  1.0) return vec3(0.0, 1.0, 0.0);
    return vec3(x);
}

vec3 colorDebugEdges(float x) {
    if (isnan(x)) return vec3(1.0, 0.0, 1.0);
    if (isinf(x)) return vec3(1.0, 0.0, 0.0);
    if (x <  0.0) return vec3(0.0, 0.0, 1.0);
    if (x == 0.0) return vec3(0.0, 0.0, 0.1);
    if (x == 1.0) return vec3(0.9, 1.0, 0.9);
    if (x >  1.0) return vec3(0.0, 1.0, 0.0);
    return vec3(x);
}

vec3 checkBarycentrics(vec4 bary) {
    if (bary.x < 0.0 || bary.y < 0.0 || bary.z < 0.0 || bary.w < 0.0) return vec3(0.0, 0.0, 1.0);
    if (bary.x > 1.0 || bary.y > 1.0 || bary.z > 1.0 || bary.w > 1.0) return vec3(1.0, 0.0, 0.0);
    if (dot(bary, vec4(1.0)) > 1.0) return vec3(1.0, 0.0, 1.0);
    if (dot(bary, vec4(1.0)) < 1.0) return vec3(0.0, 1.0, 1.0);
    return vec3(0.0, 1.0, 0.0);
}
vec3 checkBarycentrics(vec3 bary) { return checkBarycentrics(vec4(bary, 0.0)); }
vec3 checkBarycentrics(vec2 bary) { return checkBarycentrics(vec4(bary, 0.0, 0.0)); }