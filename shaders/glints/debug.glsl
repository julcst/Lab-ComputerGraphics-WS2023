#if 1 // Enable or disable debug macros
#define RENDER_VIEW(c) if (uDebug == 0U) fragColor = c
#define DEBUG_VIEW(i, v) if (uDebug == uint(i)) fragColor = v
#else
#define RENDER_VIEW(c) fragColor = c
#define DEBUG_VIEW(i, v)
#endif

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