#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
in vec3 worldPos;
out vec3 fragColor;

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#line 12 104

void main() {
    // Renormalize because of interpolation
    vec3 N = normalize(n);
    // Calculate view vector
    vec3 V = normalize(uCameraPosition - worldPos);
    // Calculate GGX BRDF
    fragColor = BRDF_ggx(N, uLightDir, V, uAlbedo, uMetallic, uRoughness) * uLightColor * max(dot(uLightDir, N), 0.0);
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}