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
#include "shared/debug.glsl"
#include "shared/tangentspace.glsl"
#line 16 105

void main() {
    mat3 worldToTangent = calcWorldToTangentMatrix(worldNormal, worldTangent);

    // Normal vector in tangent space
    vec3 N = vec3(0.0, 0.0, 1.0);
    // View vector in tangent space
    vec3 V = worldToTangent * normalize(uCameraPosition - worldPosition);
    // Light vector in tangent space
    vec3 L = worldToTangent * uLightDir;
    // H is the half vector between L and V
    vec3 H = normalize(V + L);
    
    // Calculate dot products
    float NdotV = V.z; //dot(N, V);
    float NdotL = L.z; //dot(N, L);
    float NdotH = H.z; //dot(N, H);
    float HdotV = dot(H, V);
    float NcdotV = max(NdotV, 0.0);
    float NcdotL = max(NdotL, 0.0);
    float NcdotH = max(NdotH, 0.0);
    float HcdotV = max(HdotV, 0.0);

/////////// Calculate FGD after GGX microfacet model ///////////

    // Remap roughness
    float a = uRoughness * uRoughness;
    float k = k_direct(a);

    // F is the Fresnel term
    vec3 F = F_schlick(HdotV, uAlbedo, uMetallic);
    // G is the geometric shadowing term
    float G = uEnableAccurateGGX ? G_TrowbridgeReitz(NdotV, NdotL, a) : G_smith_ggx(NdotV, NdotL, k);
    // D is the microfacet distribution term
    // This is the target to which we converge with increasing microfacet count 
    float D = uEnableAccurateGGX ? D_TrowbridgeReitz(NdotH, a) : D_ggx(NdotH, a);

/////////// Evaluating the rendering equation ///////////

    // Calculate the specular component with Cook-Torrance model
    vec3 specular = (F * G * D) / (4.0 * NdotV * NdotL); // Equation (2)
    if (any(isnan(specular))) specular = vec3(0.0);

    // Calculate the diffuse component with Lambertian model
    vec3 diffuse = (vec3(1.0) - F) * (1.0 - uMetallic) * uAlbedo / 3.14159265359;

    vec3 brdf = specular + diffuse;

    // Solve the rendering equation
    vec3 lighting = brdf * uLightColor * NcdotL; // Equation (1)

    // Fake ambient lighting
    lighting += uSkyColor * uAlbedo * uAmbientStrength;

    RENDER_VIEW(lighting);
}