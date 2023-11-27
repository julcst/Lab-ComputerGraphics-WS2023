#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
in vec3 worldPos;
out vec3 fragColor;

#include "uniforms.glsl"
#include "ggx.glsl"
#include "glints/binom.glsl"
#include "glints/random.glsl"

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

    // Calculate the UV derivatives
    vec2 duvdx = uScreenSpaceScale * dFdx(uv);
    vec2 duvdy = uScreenSpaceScale * dFdy(uv);
    // The area of the pixel footprint
    // Measured as the area of the parallelogram spanned by the two partial derivatives
    float footprint = 0.5 * length(cross(vec3(duvdx, 0.0), vec3(duvdy, 0.0)));

    // Generate incoherent random numbers based on the uv coordinates
    vec3 rand = hash3f(vec3(uv.xy, uv.x * uv.y));

    // p ist the probability for a single microfacet to be reflecting
    float p = uMicrofacetRoughness * D / Dmax;

    // Randomize the microfacet density
    float logDensityRand = clamp(sampleNormal(uLogMicrofacetDensity, uDensityRandomization, rand.x), 0.0, 50.0);
    // NP is the number of discrete microfacets in the pixel footprint
    float NP = max(0.0, footprint * exp(logDensityRand));
    // c is the number of reflecting microfacets in the pixel footprint
    float c = (Dmax / uMicrofacetRoughness) * sampleBinom(NP, p, rand.yz); // Equation (4)
    // DP is the microfacet distribution term over the pixel footprint
    float DP = c / NP; // Equation (3)

/////////// Glint rendering ///////////

    // Calculate the specular component with Cook-Torrance model
    vec3 specular = (F * G * DP) / (4.0 * NdotL * NdotV + 0.0001); // Equation (2)

    // Calculate the diffuse component with Lambertian model
    vec3 diffuse = (vec3(1.0) - F) * (1.0 - uMetallic) * uAlbedo / 3.14159265359;

    vec3 brdf = specular + diffuse;

    // Solve the rendering equation
    vec3 lighting = brdf * uLightColor * NdotL; // Equation (1)

    // Fake ambient lighting
    lighting += uSkyColor * uAlbedo * uAmbientStrength;

    // Draw color to screen
    fragColor = lighting;
}