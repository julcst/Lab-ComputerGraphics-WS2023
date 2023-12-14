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
#define GDEBUG_major(v) DEBUG_VIEW(7, v)
#define GDEBUG_grid(v) DEBUG_VIEW(8, v)
#define GDEBUG_lodWeight(v) DEBUG_VIEW(9, v)
#define GDEBUG_anisoWeight(v) DEBUG_VIEW(10, v)
#define GDEBUG_thetaWeight(v) DEBUG_VIEW(11, v)
#define GDEBUG_centerCase(v) DEBUG_VIEW(12, v)

/**
 * Interprets angle as hue and converts it to RGB.
 */
vec3 angleToRGB(float angle) {
    float angle01 = angle / 6.283 + 0.5;
    return clamp(abs(mod(angle01 * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

vec3 normalToRGB(vec3 normal) {
    return normal * 0.5 + 0.5;
}

vec3 normalToRGB(vec2 normal) {
    return vec3(normal * 0.5 + 0.5, 0.0);
}

vec3 boolToRGB(bool b) {
    return b ? vec3(1.0) : vec3(0.0);
}