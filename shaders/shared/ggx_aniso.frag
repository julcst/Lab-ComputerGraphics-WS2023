#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
in vec3 t;
in vec3 b;
in vec3 worldPos;
out vec3 fragColor;

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#line 12 104

void main() {
    // Renormalize because of interpolation
    vec3 N = normalize(n);
    vec3 T = normalize(t);
    vec3 B = normalize(b);

    //Transformation Matrix
    mat3 TBN = mat3(T, B, N);
    mat3 TBN_t = transpose(TBN);

    // Calculate view vector
    vec3 V = normalize(uCameraPosition - worldPos);
    //Light vector
    vec3 L = normalize(uLightDir);

    //transform to tangent space
    V = TBN_t * V;
    L = TBN_t * L;

    // Calculate GGX BRDF
    fragColor = BRDF_ggx_aniso(N, L, V, uAlbedo, uMetallic, uAlphaX, uAlphaY) * uLightColor * max(dot(L, N), 0.0);
    // Fake ambient lighting
    fragColor += uSkyColor * uAlbedo * uAmbientStrength;
}