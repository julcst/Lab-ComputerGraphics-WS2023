#version 330 core

in VertexData {
    vec2 uv;
    vec3 worldPosition;
    vec3 worldNormal;
    vec3 tangentLightDir;
    vec3 tangentViewDir;
};
out vec3 fragColor;

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#line 15 104

void main() {
    // Renormalize because of interpolation
    vec3 N = normalize(n);
    // Calculate view vector
    vec3 V = tangentViewDir;
    //Light vector
    vec3 L = normalize(uLightDir);

    // Calculate GGX BRDF
    fragColor = BRDF_ggx_aniso(N, L, V, uAlbedo, uMetallic, uAlphaX, uAlphaY) * uLightColor * max(dot(L, N), 0.0);
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}