#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
out vec3 fragColor;

#include "uniforms.glsl"
#include "ggx.glsl"

void main() {
    // Renormalize because of interpolation
    vec3 N = normalize(n);
    // The reflectance equation using lambertian reflectance
    fragColor = BRDF_lambert(uAlbedo) * uLightColor * max(dot(uLightDir, n), 0.0);
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}