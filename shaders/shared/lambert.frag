#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
out vec3 fragColor;

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#line 11 106

void main() {
    // Renormalize because of interpolation
    vec3 N = normalize(n);
    // The reflectance equation using lambertian reflectance
    fragColor = BRDF_lambert(uAlbedo) * uLightColor * max(dot(uLightDir, N), 0.0);
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}