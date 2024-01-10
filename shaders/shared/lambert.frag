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
#line 15 106

void main() {
    // Renormalize because of interpolation
    vec3 N = vec3(0.0, 0.0, 1.0);
    vec3 L = tangentLightDir;

    float NdotL = max(dot(N, L), 0.0);

    // The reflectance equation using lambertian reflectance
    fragColor = BRDF_lambert(uAlbedo) * uLightColor * NdotL;
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}