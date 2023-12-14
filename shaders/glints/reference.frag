#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
in vec3 worldPos;
out vec3 fragColor;

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#include "shared/debug.glsl"
#include "glints/reference.glsl"

#line 15 207

void main() {

    // N is the surface normal in world space
    vec3 N = normalize(n);
    // L is the light direction in world space
    vec3 L = uLightDir;
    // V is the view direction in world space
    vec3 V = normalize(uCameraPosition - worldPos);
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
    // NOTE: Instead of the local half vector we pass the world space H
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