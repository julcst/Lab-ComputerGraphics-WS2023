#line 2 301

/*
* Common functions for the implementation of
* Belcour, Laurent. "Efficient rendering of layered materials using an atomic decomposition with statistical operators." ACM Transactions on Graphics 37.4 (2018): 1.
*/

#include "shared/ggx.glsl"

/**
 * check if vec3 == vec3(0.0)
 */
bool isZero(vec3 v){
    return v.x == 0.0 && v.y == 0.0 && v.z == 0.0;
}

 /**
  * average of a vec3
  */
float average(vec3 v){
    return (v.x + v.y + v.z)/3;
}

/**
 * mapping from roughness to linear variance
 * equation 6 from paper
 * 
 * @param a roughness alpha
 * @return linear variance sigma
 */
float roughnessToVariance(float a){
    a = clamp(a, 0.0, 0.99999);
    float a11 = pow(a, 1.1);
    return a11 / (1.0 - a11);
}

/**
 * vec2 overload of roughnessToVariance
 */
 vec2 roughnessToVariance(vec2 a){
    return vec2(roughnessToVariance(a.x), roughnessToVariance(a.y));
 }

/**
 * mapping from linear variance to roughness
 * equation 6 from paper
 * 
 * @param sigma linear variance
 * @return roughness alpha
 */
float varianceToRoughness(float sigma){
    return pow((sigma / (1.0 + sigma)),(1.0/1.1));
}

/**
 * vec2 overload of varianceToRoughness
 */
 vec2 varianceToRoughness(vec2 sigma){
    return vec2(varianceToRoughness(sigma.x), varianceToRoughness(sigma.y));
 }

/**
 * roughness scale factor for fake transmission
 * equation 10 from paper
 * 
 * @param n12 = n1 / n2 IOR
 * @param NdotL
 * @param NdotV 
 * @return scale factor s
 */
float s(float n12, float cosTheta_I, float cosTheta_T){
    return 0.5 * (1 + n12 * (cosTheta_I/cosTheta_T));
}

/**
 * mapping from Henyey-Greenstein's anisotropy factor g to variance
 * equation 21 from paper
 * 
 * @param g HG's anisotropy factor
 * @return variance sigma_g
 */
float gToVariance(float g){
    g = clamp(g, 0.00001, 1.0);
    return pow(((1-g)/g), 0.8) * (1/(1+g));
}

/**
 * Fresnel for dielectrics
 * implementation following https://pbr-book.org/3ed-2018/Reflection_Models/Specular_Reflection_and_Transmission
 * 
 * @param cosTheta Theta is the angle between the surface normal and the incident ray
 * @param etaI IOR of the incident media
 * @param etaT IOR of the transmitted media
 * @return Fresnel reflectance
 */
 float F_dielectric(float cosThetaI, float etaI, float etaT){
    cosThetaI = clamp(cosThetaI, -1.0, 1.0);

    bool entering = cosThetaI > 0.f;
    if (!entering) {
        //swap
        float tmp = etaI;
        etaI = etaT;
        etaT = tmp;
        cosThetaI = abs(cosThetaI);
    }

    //compute cosThetaT using Snell’s law
    float sinThetaI = sqrt(max(0.0, 1.0 - pow(cosThetaI,2)));
    float sinThetaT = etaI / etaT * sinThetaI; 
    //total internal reflection
    if (sinThetaT >= 1) return 1.0;
    float cosThetaT = sqrt(max(0.0, 1 - pow(sinThetaT,2)));

    float r_parallel = ((etaT * cosThetaI) - (etaI * cosThetaT)) / ((etaT * cosThetaI) + (etaI * cosThetaT));
    float r_orthogonal = ((etaI * cosThetaI) - (etaT * cosThetaT)) / ((etaI * cosThetaI) + (etaT * cosThetaT));

    return (pow(r_parallel,2) + pow(r_orthogonal,2)) / 2.0;
 }

/**
 * Fresnel for dielectrics
 * vec3 overload
 */
vec3 F_dielectric(float cosThetaI, vec3 etaI, vec3 etaT){
    vec3 F = vec3(0.0);
    F.x = F_dielectric(cosThetaI, etaI.x, etaT.x);
    F.y = F_dielectric(cosThetaI, etaI.y, etaT.y);
    F.z = F_dielectric(cosThetaI, etaI.z, etaT.z);
    return F;
}


/**
 * complex division
 *
 * @param x1
 * @param x2
 * @return x1 / x2
 */
 vec2 complexDivide(vec2 numerator, vec2 denominator){
    float a = numerator.x;
    float b = numerator.y;
    float c = denominator.x;
    float d = denominator.y;
    vec2 result;
    float denom = pow(c,2) + pow(d,2);
    result.x = (a*c + b*d)/denom;
    result.y = (b*c - a*d)/denom;
    return result;
 }

 /**
 * Fresnel for conductor
 * implementation following https://pbr-book.org/3ed-2018/Reflection_Models/Specular_Reflection_and_Transmission
 * 
 * @param cosTheta Theta is the angle between the surface normal and the incident ray
 * @param IOR_I complex IOR of the incident media
 * @param IOR_T complex IOR of the transmitted media
 * @return Fresnel reflectance
 */
 float F_conductor(float cosTheta, vec2 IOR_I, vec2 IOR_T){
    vec2 IOR = complexDivide(IOR_T, IOR_I);
    float eta = IOR.x;
    float kappa = IOR.y;

    float cosTheta_2 = pow(cosTheta,2);
    float sinTheta_2 = 1.0 - cosTheta_2;
    float sinTheta_4 = pow(sinTheta_2,2);

    float temp_1 = pow(eta,2) - pow(kappa,2) - sinTheta_2;
    float a2_p_b2 = sqrt(pow(temp_1,2) + 4.0 * pow(eta,2) * pow(kappa,2));
    float a = sqrt(0.5 * (a2_p_b2 + temp_1));

    float term1 = a2_p_b2 + cosTheta_2;
    float term2 = 2.0 * a * cosTheta;

    float r_orthogonal = (term1 - term2) / (term1 + term2);

    float term3 = cosTheta_2 * a2_p_b2 + sinTheta_4;
    float term4 = term2 * sinTheta_2;

    float r_parallel = r_orthogonal * ((term3 - term4)/(term3 + term4));

    return (r_parallel + r_orthogonal) / 2;
 }

/**
 * Fresnel for conductors
 * vec3 overload
 */
vec3 F_conductor(float cosThetaI, vec3 etaI, vec3 kappaI, vec3 etaT, vec3 kappaT){
    vec3 F = vec3(0.0);
    vec2 IOR_I = vec2(etaI.x, kappaI.x);
    vec2 IOR_T = vec2(etaT.x, kappaT.x);
    F.x = F_conductor(cosThetaI, IOR_I, IOR_T);
    IOR_I = vec2(etaI.y, kappaI.y);
    IOR_T = vec2(etaT.y, kappaT.y);
    F.y = F_conductor(cosThetaI, IOR_I, IOR_T);
    IOR_I = vec2(etaI.z, kappaI.z);
    IOR_T = vec2(etaT.z, kappaT.z);
    F.z = F_conductor(cosThetaI, IOR_I, IOR_T);
    return F;
}

/**
 * Calculates FGD after GGX microfacet model
 * 
 * @param N surface normal
 * @param L light direction (wi)
 * @param V view direction (wo)
 * @param alpha roughness
 * @param etaI real part of complex IOR of the incident media
 * @param etaI imaginary part of complex IOR of the incident media
 * @param etaI real part of complex IOR of the transmitted media
 * @param etaI imaginary part of complex IOR of the transmitted media
 * @return FDG
 */
vec3 evalFGD(vec3 N, vec3 L, vec3 V, float alpha, vec3 etaI, vec3 kappaI, vec3 etaT, vec3 kappaT){
    vec3 FGD = vec3(0.0);

    // H is the half vector between L and V
    vec3 H = normalize(V + L);

    // Calculate dot products
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);

    //remap roughness
    float k = k_direct(alpha);

    //fresnel term
    vec3 F = vec3(0.0);
    if(isZero(kappaT)){
        F = F_dielectric(NdotL, etaI, etaT);
    }else{
        F = F_conductor(NdotL, etaI, kappaI, etaT, kappaT);
    }
    
    //geometric shadowing term
    float G = G_smith_ggx(NdotV, NdotL, k);

    //microfacet distribution term
    float D = D_ggx(NdotH, alpha);

    //equation 2 from paper
    FGD = F * G * D * NdotL;
    float denom = 4.0 * NdotL * NdotV + 0.0001;
    FGD = FGD / denom;

    return FGD;
}

/**
 * Calculates the Fresnel equation
 * 
 * @param cosTheta_I
 * @param etaI real part of complex IOR of the incident media
 * @param etaI imaginary part of complex IOR of the incident media
 * @param etaI real part of complex IOR of the transmitted media
 * @param etaI imaginary part of complex IOR of the transmitted media
 * @return F
 */
vec3 evalFresnel(float cosTheta_I, vec3 etaI, vec3 kappaI, vec3 etaT, vec3 kappaT){
    vec3 F = vec3(0.0);

    if(isZero(kappaT)){
        F = F_dielectric(cosTheta_I, etaI, etaT);
    }else{
        F = F_conductor(cosTheta_I, etaI, kappaI, etaT, kappaT);
    }

    return F;
}