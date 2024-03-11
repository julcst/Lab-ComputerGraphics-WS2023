#line 2 106
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
 * Trowbridge-Reitz (GGX) approximation of normal distribution function
 * From: PBR-Book
 * Returns the differential area of microfacets oriented with the halfway vector w_h.
 */
float D_TrowbridgeReitz(float NdotH, float a) {
    float cosTheta = NdotH;
    float cos2Theta = cosTheta * cosTheta;
    float sin2Theta = max(1.0 - cos2Theta, 0.0);
    // float sinTheta = sqrt(sin2Theta);
    // float tanTheta = sinTheta / cosTheta;
    float tan2Theta = sin2Theta / cos2Theta;

    if (isinf(tan2Theta)) return 0.0;

    float cos4Theta = cos2Theta * cos2Theta;

    float a2 = a * a;
    float e = tan2Theta / a2;
    return 1.0 / (PI * a2 * cos4Theta * (1.0 + e) * (1.0 + e));
}

/**
 * From: PBR-Book
 * Measures invisible masked microfacet area per visible microfacet area.
 */
float Lambda_TrowbridgeReitz(float NdotV, float alpha) {
    float cosTheta = NdotV;
    float cos2Theta = cosTheta * cosTheta;
    float sin2Theta = max(1.0 - cos2Theta, 0.0);
    float sinTheta = sqrt(sin2Theta);
    float tanTheta = sinTheta / cosTheta;
    float absTanTheta = abs(tanTheta);

    if (isinf(absTanTheta)) return 0.0;

    float alpha2Tan2Theta = (alpha * absTanTheta) * (alpha * absTanTheta);
    return (-1.0 + sqrt(1.0 + alpha2Tan2Theta)) / 2.0;
}

/**
 * From: PBR-Book
 * Returns the fraction of microfacets with normal w_h that are visible from direction V.
 */
float G1_TrowbridgeReitz(float NdotV, float a) {
    return 1.0 / (1.0 + Lambda_TrowbridgeReitz(NdotV, a)); 
}

/**
 * From: PBR-Book
 * Returns the fraction of microfacets that are visible from both view and light direction. 
 */
float G_TrowbridgeReitz(float NdotV, float NdotL, float a) {
    return 1.0 / (1.0 + Lambda_TrowbridgeReitz(NdotV, a) + Lambda_TrowbridgeReitz(NdotL, a)); 
}


/**
 * Trowbridge-Reitz (GGX) approximation of normal distribution function
 */
float D_ggx(float NdotH, float a) {
    float a2     = a * a;
    float NdotH2 = NdotH * NdotH;
	
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
 */
vec3 BRDF_ggx(float NdotV, float NdotL, float NdotH, float HdotV, vec3 albedo, float metallic, float roughness) {
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


/**
 * Anisotropic GGX BRDF implementation following Aakash KT, Eric Heitz, Jonathan Dupuy, and P. J. Narayanan. 2022. Bringing Linearly Transformed Cosines to Anisotropic GGX. In Proceedings of SIGGRAPH I3D (I3D’22). ACM, New York, NY, USA, 9 pages.
 */

/**
 * Normal Distribution Function
 */
float D_ggx_aniso(vec3 H, float alphaX, float alphaY) {
    return 1 / (PI * alphaX * alphaY * pow(((H.x * H.x)/(alphaX*alphaX) + (H.y * H.y)/(alphaY*alphaY) + (H.z*H.z)),2));
}

/**
 * Masking-shadowing function
 */
float Lambda_ggx(vec3 w, float alphaX, float alphaY){
    return (-1 + sqrt(1 + (((alphaX*alphaX*w.x*w.x) + (alphaY*alphaY*w.y*w.y))/(w.z*w.z)))) / 2;
}

float G2_ggx_aniso(vec3 V, vec3 L, float alphaX, float alphaY) {
return 1 / (1 + Lambda_ggx(V, alphaX, alphaY) + Lambda_ggx(L, alphaX, alphaY));
}

float G1_ggx_aniso(vec3 V, float alphaX, float alphaY) {
    return 1 / (1 + Lambda_ggx(V, alphaX, alphaY));
}

/**
 * Anisotropic GGX BRDF
 * @param N Surface normal in tangent space
 * @param L Light direction in tangent space
 * @param V View direction in tangent space
 */
vec3 BRDF_ggx_aniso(vec3 N, vec3 L, vec3 V, vec3 albedo, float metallic, float alphaX, float alphaY) {
    // H is the half vector between L and V
    vec3 H = normalize(V + L);

    // Calculate dot products
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    vec3 F = F_schlick(HdotV, albedo, metallic);

    // Calculate the specular component with GGX
    vec3 FGD = F * G2_ggx_aniso(V, L, alphaX, alphaY) * D_ggx_aniso(H, alphaX, alphaY);
    float denom = 4.0 * NdotL * NdotV + 0.0001;
    vec3 specular = FGD / denom;

    // Calculate the diffuse component with Lambert
    vec3 diffuse = diffuse(F, albedo, metallic);

    return specular + diffuse;
}

/*
 * GGX sampling from 
 * Eric Heitz, Sampling the GGX Distribution of Visible Normals, Journal of Computer Graphics Techniques (JCGT), vol. 7, no. 4, 1-13, 2018
 *
 * @param V View direction
 * @param alphaX rouhgness
 * @param alphaY rouhgness
 * @param U1 random number
 * @param U2 random number
 * @return normal sampled with PDF D_V(Ne) = G1(V) * max(0, dot(V, Ne)) * D(Ne) / V.z
 */
vec3 sampleGGXVNDF(vec3 V, float alphaX, float alphaY, float U1, float U2)
{
	// Section 3.2: transforming the view direction to the hemisphere configuration
	vec3 Vh = normalize(vec3(alphaX * V.x, alphaY * V.y, V.z));
	// Section 4.1: orthonormal basis (with special case if cross product is zero)
	float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
	vec3 T1 = lensq > 0 ? vec3(-Vh.y, Vh.x, 0) / sqrt(lensq) : vec3(1,0,0);
	vec3 T2 = cross(Vh, T1);
	// Section 4.2: parameterization of the projected area
	float r = sqrt(U1);	
	float phi = 2.0 * PI * U2;	
	float t1 = r * cos(phi);
	float t2 = r * sin(phi);
	float s = 0.5 * (1.0 + Vh.z);
	t2 = (1.0 - s)*sqrt(1.0 - t1*t1) + s*t2;
	// Section 4.3: reprojection onto hemisphere
	vec3 Nh = t1*T1 + t2*T2 + sqrt(max(0.0, 1.0 - t1*t1 - t2*t2))*Vh;
	// Section 3.4: transforming the normal back to the ellipsoid configuration
	vec3 Ne = normalize(vec3(alphaX * Nh.x, alphaY * Nh.y, max(0.0, Nh.z)));	
	return Ne;
}