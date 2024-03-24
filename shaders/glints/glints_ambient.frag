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
#include "shared/lowdiscrepancysequence.glsl"
#include "glints/glints.glsl"
#line 18 204

void main() {
    mat3 worldToTangent = calcWorldToTangentMatrix(worldNormal, worldTangent);

    // Normal vector in tangent space
    vec3 N = vec3(0.0, 0.0, 1.0);
    // View vector in tangent space
    vec3 V = worldToTangent * normalize(uCameraPosition - worldPosition);
    // Light vector in tangent space
    vec3 L = reflect(-V, N);//worldToTangent * uLightDir;
    vec3 lightColor = uLightColor;
    // H is the half vector between L and V
    vec3 H = N;//normalize(V + L);
    
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
    float DP = D_glints(D, Dmax, V, uv, uScreenSpaceScale, uMicrofacetRoughness, uLogMicrofacetDensity, uDensityRandomization);

/////////// Evaluating the rendering equation ///////////

    // Calculate the specular component with Cook-Torrance model
    vec3 specular = (F * G * DP) / (4.0 * NdotV * NdotL); // Equation (2)
    if (any(isnan(specular))) specular = vec3(0.0);

    // Calculate the diffuse component with Lambertian model
    vec3 diffuse = (vec3(1.0) - F) * (1.0 - uMetallic) * uAlbedo / 3.14159265359;

    vec3 brdf = specular + diffuse;

    // if (uUseCubemap) {
    //     uint SAMPLE_COUNT = 5u;
    //     lightColor = vec3(0.0);
    //     for(uint s = 0u; s < SAMPLE_COUNT; s++){
    //         // hammersley sequence to generate low-discrepancy points
    //         vec2 U = hammersley(s, SAMPLE_COUNT);
    //         vec3 H_sample = sampleGGXVNDF(V, a, a, U.x, U.y);
    //         vec3 L_sample = reflect(-V, H);
    //         vec3 L_sample_world = transpose(worldToTangent) * L_sample;
    //         float D_sample = D_TrowbridgeReitz(dot(N, H_sample), a);

    //         float pdf = (D_sample * dot(N, H_sample) / (4.0 * dot(H_sample, V))) + 0.0001;

    //         ivec2 resolution = textureSize(cubemap, 0); // resolution of source cubemap (per face)
    //         float saTexel  = 4.0 * PI / (6.0 * resolution.x * resolution.y);
    //         float saSample = 1.0 / (pdf + 0.0001);

    //         float mipLevel = max(0.5 * log2(saSample / saTexel) + 1.0, 0.0); 

    //         lightColor += textureLod(cubemap, L_sample_world, mipLevel).rgb;
    //     }
    //     lightColor /= SAMPLE_COUNT;
    // }

    if (uUseCubemap) {
        vec3 L_world = transpose(worldToTangent) * L;
        
        float pdf = (D * NdotH / (4.0 * HdotV)) + 0.0001;

        ivec2 resolution = textureSize(cubemap, 0); // resolution of source cubemap (per face)
        float saTexel  = 4.0 * PI / (6.0 * resolution.x * resolution.y);
        float saSample = 1.0 / (pdf + 0.0001);

        float mipLevel = max(0.5 * log2(saSample / saTexel) + 1.0, 0.0); 

        lightColor = textureLod(cubemap, L_world, mipLevel).rgb;
    }

    // Solve the rendering equation
    vec3 lighting = brdf * lightColor * NcdotL; // Equation (1)

    RENDER_VIEW(lighting);
    GDEBUG_D(colorDebug(D));
    GDEBUG_Dmax(vec3(Dmax));
    GDEBUG_DP(colorDebug(DP));
}