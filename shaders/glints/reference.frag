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
#include "glints/reference.glsl"
#line 17 208

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
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);

/////////// Calculate FGD after GGX microfacet model ///////////

    // Remap roughness
    float a = uRoughness * uRoughness;
    float k = k_direct(a);

    // F is the Fresnel term
    vec3 F = F_schlick(HdotV, uAlbedo, uMetallic);
    // G is the geometric shadowing term
    float G = G_smith_ggx(NdotV, NdotL, k);
    // D is the microfacet distribution term
    // This is the target to which we converge with increasing microfacet count 
    float D = D_ggx(NdotH, a);
    // Dmax is the distribution term at the shading normal
    // This is the maximum possible value for the distribution term and is used to ensure that p remains in [0, 1]
    float Dmax = D_ggx(1.0, a); // NdotN = 1.0

/////////// Glint rendering ///////////

    // Extend the distribution term with a stochastic microfacet counting process to account
    // for the microfacet distribution inside the pixel footprint
    // TODO: Currently instead of the half vector in tangent space we pass H in world space
    float DP = SampleGlints2023NDF(H, D, Dmax, uv, dFdx(uv), dFdy(uv));

/////////// Evaluating the rendering equation ///////////

    // Calculate the specular component with Cook-Torrance model
    vec3 specular = (F * G * DP) / (4.0 * NdotL * NdotV + 0.0001); // Equation (2)

    // Calculate the diffuse component with Lambertian model
    vec3 diffuse = (vec3(1.0) - F) * (1.0 - uMetallic) * uAlbedo / 3.14159265359;

    vec3 brdf = specular + diffuse;

    // Solve the rendering equation
    vec3 lighting = brdf * uLightColor * NdotL; // Equation (1)

    // Fake ambient lighting
    lighting += uSkyColor * uAlbedo * uAmbientStrength;

    RENDER_VIEW(lighting);
    GDEBUG_D(vec3(D));
    GDEBUG_Dmax(vec3(Dmax));
    GDEBUG_DP(vec3(DP));
}