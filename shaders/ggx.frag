#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
in vec3 worldPos;
out vec3 fragColor;

#include "uniforms.glsl"
#include "ggx.glsl"

// FIXME: When rotating a sphere the specular highlight is moving
void main() {
    // Renormalize because of interpolation
    vec3 N = normalize(n);
    // Calculate view vector
    vec3 V = normalize(uCameraPosition - worldPos);
    // Calculate GGX BRDF
    fragColor = BRDF_ggx(N, uLightDir, V, uAlbedo, uMetallic, uRoughness) * uLightColor * max(dot(uLightDir, n), 0.0);
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}