#line 2 105
/**
 * GGX Cook-Torrance BRDF implementation following https://learnopengl.com/PBR by Joey de Vries
 */

const float PI = 3.14159265359;

/**
 * Schlick approximation of Fresnel term
 */
vec3 F_schlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

/**
 * Schlick approximation of Fresnel term with physically plausible F0
 */
vec3 F_schlick(float cosTheta, vec3 albedo, float metallic) {
    vec3 F0 = vec3(0.04); // Physically plausible default value for dielectrics
    F0 = mix(F0, albedo, metallic); // Tint the Fresnel base reflectivity for metallic surfaces
    return F_schlick(cosTheta, F0);
}

/**
 * Trowbridge-Reitz GGX approximation of normal distribution function
 */
float D_ggx(float NdotH, float a) {
    float a2     = a*a;
    float NdotH2 = NdotH*NdotH;
	
    float nom    = a2;
    float denom  = (NdotH2 * (a2 - 1.0) + 1.0);
    denom        = PI * denom * denom;
	
    return nom / denom;
}

float G_schlick_ggx(float NdotV, float k) {
    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;
	
    return nom / denom;
}

/**
 * Smith's Schlick-GGX approximation of geometric shadowing function
 */
float G_smith_ggx(float NdotV, float NdotL, float k) {
    float ggx1 = G_schlick_ggx(NdotV, k);
    float ggx2 = G_schlick_ggx(NdotL, k);
	
    return ggx1 * ggx2;
}

/**
 * Remapping a to k for direct lighting
 */
float k_direct(float a) {
    float a1 = a + 1.0;
    return a1 * a1 / 8.0;
}

/**
 * Approximates the diffuse component of the BRDF with a Lambert BRDF
 */
vec3 diffuse(vec3 F, vec3 albedo, float metallic) {
    vec3 kD = vec3(1.0) - F;
    kD *= 1.0 - metallic;
    return kD * albedo / PI;
}

/**
 * The Lambert BRDF
 */
vec3 BRDF_lambert(vec3 albedo) {
    return albedo / PI;
}

/**
 * The GGX Cook-Torrance BRDF
 * @param N Surface normal in world space
 * @param L Light direction in world space
 * @param V View direction in world space
 */
vec3 BRDF_ggx(vec3 N, vec3 L, vec3 V, vec3 albedo, float metallic, float roughness) {
    // H is the half vector between L and V
    vec3 H = normalize(V + L);

    // Calculate dot products
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    // Remap roughness
    float a = roughness * roughness;
    float k = k_direct(a);

    vec3 F = F_schlick(HdotV, albedo, metallic);

    // Calculate the specular component with Cook-Torrance GGX
    vec3 FGD = F * G_smith_ggx(NdotV, NdotL, k) * D_ggx(NdotH, a);
    float denom = 4.0 * NdotL * NdotV + 0.0001;
    vec3 specular = FGD / denom;

    // Calculate the diffuse component with Lambert
    vec3 diffuse = diffuse(F, albedo, metallic);

    return specular + diffuse;
}