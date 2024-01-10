#version 330 core

in VertexData {
    vec2 uv;
    vec3 worldPosition;
    vec3 worldNormal;
    vec3 tangentLightDir;
    vec3 tangentViewDir;
    vec3 tangentPosition;
    vec3 tangentViewPosition;
};
out vec3 fragColor;

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#line 15 104

void main() {
    // The normal is (0, 0, 1) in tangent space
    vec3 N = vec3(0.0, 0.0, 1.0);
    // Calculate view vector
    vec3 V = normalize(tangentViewPosition - tangentPosition);
    vec3 L = normalize(tangentLightDir);
    // H is the half vector between L and V
    vec3 H = normalize(V + L);

    // Calculate dot products
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    // Calculate GGX BRDF
    fragColor = BRDF_ggx(NdotV, NdotL, NdotH, NdotV, uAlbedo, uMetallic, uRoughness) * uLightColor * NdotL;
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}