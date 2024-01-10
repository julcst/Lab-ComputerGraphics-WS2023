#version 330 core

in VertexData {
    vec2 uv;
    vec3 worldPosition;
    vec3 worldNormal;
    vec3 worldTangent;
};
out vec3 fragColor;

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#include "shared/tangentspace.glsl"
#line 14 107

void main() {
    mat3 worldToTangent = calcWorldToTangentMatrix(worldNormal, worldTangent);

    // Normal vector in tangent space
    vec3 N = vec3(0.0, 0.0, 1.0);
    // View vector in tangent space
    vec3 V = worldToTangent * normalize(uCameraPosition - worldPosition);
    // Light vector in tangent space
    vec3 L = worldToTangent * uLightDir;

    float NdotL = max(dot(N, L), 0.0);

    // The reflectance equation using lambertian reflectance
    fragColor = BRDF_lambert(uAlbedo) * uLightColor * NdotL;
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}