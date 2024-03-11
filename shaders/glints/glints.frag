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
#include "glints/glints.glsl"
#line 17 204

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
    // float k = k_direct(a);

    // F is the Fresnel term
    vec3 F = F_schlick(HdotV, uAlbedo, uMetallic);
    // G is the geometric shadowing term
    float G = G_TrowbridgeReitz(NdotV, NdotL, a);
    // D is the microfacet distribution term
    // This is the target to which we converge with increasing microfacet count 
    float D = D_TrowbridgeReitz(NdotH, a);
    // Dmax is the distribution term at the shading normal
    // This is the maximum possible value for the distribution term and is used to ensure that p remains in [0, 1]
    float Dmax = D_TrowbridgeReitz(1.0, a); // NdotN = 1.0

/////////// Glint rendering ///////////

    // Extend the distribution term with a stochastic microfacet counting process to account
    // for the microfacet distribution inside the pixel footprint
    float DP = D_glints(D, Dmax, H, uv, uScreenSpaceScale, uMicrofacetRoughness, uLogMicrofacetDensity, uDensityRandomization);

/////////// Evaluating the rendering equation ///////////

    // Calculate the specular component with Cook-Torrance model
    vec3 specular = (F * G * DP) / (4.0 * NdotV * NdotL); // Equation (2)
    if (any(isnan(specular))) specular = vec3(0.0);

    // Calculate the diffuse component with Lambertian model
    vec3 diffuse = (vec3(1.0) - F) * (1.0 - uMetallic) * uAlbedo / 3.14159265359;

    vec3 brdf = specular + diffuse;

    // Solve the rendering equation
    vec3 lighting = brdf * uLightColor * NcdotL; // Equation (1)

    // Fake ambient lighting
    lighting += uSkyColor * uAlbedo * uAmbientStrength;

    RENDER_VIEW(lighting);
    GDEBUG_D(colorDebug(D));
    GDEBUG_Dmax(vec3(Dmax));
    GDEBUG_DP(colorDebug(DP));
}