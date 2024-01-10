#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
in vec3 worldPos;
out vec3 fragColor;

#define MAX_LAYERS 4
#define LAYER_ARRAY_SIZE 5

#include "shared/uniforms.glsl"
#include "shared/ggx.glsl"
#include "shared/debug.glsl"

float debugX = 0.0;

/*
* Implementation of
* Belcour, Laurent. "Efficient rendering of layered materials using an atomic decomposition with statistical operators." ACM Transactions on Graphics 37.4 (2018): 1.
*/

/////////// helper functions ///////////

vec3 getLayerEta(int layerIndex){
    return uLayerEta[layerIndex].xyz;
}

vec3 getLayerKappa(int layerIndex){
    return uLayerKappa[layerIndex].xyz;
}

float getLayerAlpha(int layerIndex){
    return uLayerAlpha[layerIndex/4][layerIndex%4];
}

float getLayerDepth(int layerIndex){
    return uLayerDepth[layerIndex/4][layerIndex%4];
}

vec3 getLayerSigmaA(int layerIndex){
    return uLayerSigmaA[layerIndex].xyz;
}

vec3 getLayerSigmaS(int layerIndex){
    return uLayerSigmaS[layerIndex].xyz;
}

float getLayerG(int layerIndex){
    return uLayerG[layerIndex/4][layerIndex%4];
}

void fillLayerMaterialArrays(uint _layerCount, out vec3 _layerEta[LAYER_ARRAY_SIZE], out vec3 _layerKappa[LAYER_ARRAY_SIZE], out float _layerAlpha[LAYER_ARRAY_SIZE], out float _layerDepth[LAYER_ARRAY_SIZE], out vec3 _layerSigmaA[LAYER_ARRAY_SIZE], out vec3 _layerSigmaS[LAYER_ARRAY_SIZE], out float _layerG[LAYER_ARRAY_SIZE]){
    //air layer
    _layerEta[0] = vec3(1.0);
    _layerKappa[0] = vec3(0.0);
    _layerAlpha[0] = 0.0;
    _layerDepth[0] = 0.0;
    _layerSigmaA[0] = vec3(0.0);
    _layerSigmaS[0] = vec3(0.0);
    _layerG[0] = 0.0;
    //fill with data from uniforms or textures
    //TODO: texture lookup
    for(int i = 0; i < int(_layerCount); i++) {
        _layerEta[i+1] = getLayerEta(i);
        _layerKappa[i+1] = getLayerKappa(i);
        _layerAlpha[i+1] = getLayerAlpha(i);
        _layerDepth[i+1] = getLayerDepth(i);
        _layerSigmaA[i+1] = getLayerSigmaA(i);
        _layerSigmaS[i+1] = getLayerSigmaS(i);
        _layerG[i+1] = getLayerG(i);

        if(_layerDepth[i+1] > 0.0){
            //layer is volume -> use eta and kappa from previous interface
            _layerEta[i+1] = _layerEta[i];
            _layerKappa[i+1] = _layerKappa[i];
        }
    }
}

/////////// implementation ///////////

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

/**
 * 
 */
struct BsdfLobe {
    vec3 energy; //e
    float mean; //mu
    float variance; //sigma
};

/**
 * Adding Doubling Algorithm
 * section 5 of the paper
 * implementation without doubling
 *
 * @param N
 * @param L
 * @param V
 * @param cosThetaI
 * @param layerCount
 * @param layerIOR
 * @param layerAlpha
 * @param layerDepth
 * @param layerSigmaA
 * @param layerSigmaS
 * @param layerG
 * @param BsdfLobe
 * @param valid_lobes
 */
void addingDoubling(vec3 N, vec3 L, vec3 V, float cosThetaI, uint layerCount, vec3 layerEta[LAYER_ARRAY_SIZE], vec3 layerKappa[LAYER_ARRAY_SIZE], float layerAlpha[LAYER_ARRAY_SIZE], float layerDepth[LAYER_ARRAY_SIZE], vec3 layerSigmaA[LAYER_ARRAY_SIZE], vec3 layerSigmaS[LAYER_ARRAY_SIZE], float layerG[LAYER_ARRAY_SIZE], out BsdfLobe lobes[MAX_LAYERS], out uint valid_lobes){
    valid_lobes = 0u;
    
    float cosTheta_I = cosThetaI; //incident
    float cosTheta_T; //transmitted

    //start values for global variables (from paper page 8 paragraph Adding-Doubling)
    // 0 = top surface / stack of layers to layer i  |  i = current layer
    //energy
    vec3 energy_reflected_0i = vec3(0.0);
    vec3 energy_reflected_i0 = vec3(0.0);
    vec3 energy_transmitted_0i = vec3(1.0);
    vec3 energy_transmitted_i0 = vec3(1.0);
    //variance
    float sigma_reflected_0i = 0.0;
    float sigma_reflected_i0 = 0.0;
    float sigma_transmitted_0i = 0.0;
    float sigma_transmitted_i0 = 0.0;
    //scaling factors
    float J0i = 1.0;
    float Ji0 = 1.0;

    //iterate over layers
    for(int i = 1; i <= int(layerCount); i++){
        //extract layer data
        //index 0 = air layer | index 1 - end = actual material layer
        vec3 etaI = layerEta[i-1];
        vec3 kappaI = layerKappa[i-1];
        vec3 etaT = layerEta[i];
        vec3 kappaT = layerKappa[i];
        float n12 = average(etaT / etaI);
        float alpha = layerAlpha[i];
        float depth = layerDepth[i];
        vec3 sigma_a = layerSigmaA[i];
        vec3 sigma_s = layerSigmaS[i];
        float g = layerG[i];

        //initial values for local variables
        //energy
        vec3 energy_reflected_12 = vec3(0.0);
        vec3 energy_reflected_21 = vec3(0.0);
        vec3 energy_transmitted_12 = vec3(1.0);
        vec3 energy_transmitted_21 = vec3(1.0);
        //variance
        float sigma_reflected_12 = 0.0;
        float sigma_reflected_21 = 0.0;
        float sigma_transmitted_12 = 0.0;
        float sigma_transmitted_21 = 0.0;
        //scaling factors
        float J12 = 1.0;
        float J21 = 1.0;

        //TODO implement doubling

        //check if thin slab/interface or participating media/vloume
        if(depth > 0.0){
            //mean doesn't change
            cosTheta_T = cosTheta_I;

            /* volume absorption and scattering, from the paper Section 4.3 and 4.4*/
            //energy
            vec3 sigma_t = sigma_a + sigma_s;
            energy_transmitted_12 = (vec3(1.0) + (sigma_s * depth) / cosTheta_T) * exp(-(sigma_t * depth) / cosTheta_T); //from paper, equation 15 and 22
            energy_transmitted_21 = energy_transmitted_12;
            //variance
            sigma_transmitted_12 = gToVariance(g); //from paper, equation 24
            sigma_transmitted_21 = sigma_transmitted_12;
        }else{
            /* off-specular transmission, from the paper Section 4.2 */
            float sinTheta_I = sqrt(1.0 - pow(cosTheta_I,2));
            float sinTheta_T = sinTheta_I / n12;
            if(sinTheta_T <= 1.0){
                cosTheta_T = sqrt(1.0 - pow(sinTheta_T,2));
            }else{
                cosTheta_T = -1.0;
            }

            /* reflectance and transmittance terms for variance */
            sigma_reflected_12 = roughnessToVariance(alpha); //from paper section 4.1
            sigma_reflected_21 = sigma_reflected_12;

            //transmissive if not a conductor or total reflection
            bool transmissive = cosTheta_T > 0.0 && isZero(kappaT);
            if(transmissive){
                //from paper section 4.3, equation 13
                //TODO: check if equation from paper or equation from supplemental code works better
                sigma_transmitted_12 = roughnessToVariance(alpha * s(n12, cosTheta_I, cosTheta_T));
                sigma_transmitted_21 = roughnessToVariance(alpha * s(1.0/n12, cosTheta_T, cosTheta_I));
                
                //sigma_transmitted_12 = roughnessToVariance(alpha * 0.5f * abs(n12 - 1.0)/(n12));
                //sigma_transmitted_21 = roughnessToVariance(alpha * 0.5f * abs(1.0/n12 - 1.0)/(1.0/n12));
                
                //from paper supplemental code, layered_forward.cpp line 171
                J12 = (cosTheta_T/cosTheta_I) * n12;
                J21 = (cosTheta_I/cosTheta_T) / n12;
            }

            /* reflectance and transmittance terms for energy */
            //evaluate FGD using modified roughness accounting for top layers
            float alpha_r = varianceToRoughness(sigma_transmitted_0i + sigma_reflected_12); //from paper section 4.1, equation 9
            //vec3 FGD = evalFGD(N, L, V, alpha_r, etaI, kappaI, etaT, kappaT); //from paper section 4.1, equation 2
            vec3 FGD = evalFresnel(cosTheta_I, etaI, kappaI, etaT, kappaT); //TODO: check if FDG or just F
            energy_reflected_12 = FGD; //from paper section 4.1, equation 7 / section 5.1
            energy_transmitted_12 = 1.0 - FGD; //from paper section 4.2, equation 11 / section 5.1
            if(transmissive){
                energy_reflected_21 = energy_reflected_12; //from paper section 5.1
                energy_transmitted_21 = energy_transmitted_12; //from paper section 5.1
            }else{
                energy_reflected_21 = vec3(0.0);
                energy_transmitted_21 = vec3(0.0);
                energy_transmitted_21 = vec3(0.0);
            }

            //TODO: Total Internal Reflection using the decoupling approximation

        }

        //adding algorithm
        //multiple scattering equations on energies
        vec3 r0i = vec3(0.0);
        vec3 ri0 = vec3(0.0);
        vec3 t0i = vec3(0.0);
        vec3 ti0 = vec3(0.0);
        vec3 Rr = vec3(0.0);
        vec3 denom = vec3(1.0) - energy_reflected_12 * energy_reflected_i0; 
        if(average(denom) > 0.0){
            r0i = (energy_transmitted_0i * energy_reflected_12 * energy_transmitted_i0) / denom; //from paper section 5.1, equation 28
            ri0 = (energy_transmitted_21 * energy_reflected_i0 * energy_transmitted_12) / denom; //from paper section 5.1, equation 30
            t0i = (energy_transmitted_0i * energy_transmitted_12) / denom; //from paper section 5.1, equation 31
            ti0 = (energy_transmitted_21 * energy_transmitted_i0) / denom; //from paper section 5.1, equation 29
            Rr = (energy_reflected_12 * energy_reflected_i0) / denom;
        }

        vec3 e_R0i = energy_reflected_0i + r0i;
        vec3 e_Ri0 = energy_reflected_i0 + ri0;

        //average of energies for evaluating variance equations
        float avg_energy_reflected_0i = average(energy_reflected_0i);
        float avg_e_R0i = average(e_R0i);
        float avg_e_Ri0 = average(e_Ri0);
        float avg_r0i = average(r0i);
        float avg_ri0 = average(ri0);
        float avg_energy_reflected_21 = average(energy_reflected_21);
        float avg_Rr = average(Rr);
        

        //multiple scattering equations on variances
        float sigma_r0i = avg_energy_reflected_0i * sigma_reflected_0i + avg_r0i * (sigma_transmitted_i0 + sigma_transmitted_0i + Ji0 * (sigma_reflected_12 + avg_Rr * sigma_reflected_i0)); //from paper equation 38
        float sigma_t0i = J12 * sigma_transmitted_0i + sigma_transmitted_12 + J12 * (sigma_reflected_12 + sigma_reflected_i0) * avg_Rr; //from paper equation 49
        float sigma_ri0 = avg_energy_reflected_21 * sigma_reflected_21 + avg_ri0 * (sigma_transmitted_12 + J12 * (sigma_transmitted_21 + sigma_reflected_i0 + avg_Rr * (sigma_reflected_12 + sigma_reflected_i0))); //from paper equation 51
        float sigma_ti0 = Ji0 * sigma_transmitted_21 + sigma_transmitted_i0 + Ji0 * (sigma_reflected_12 + sigma_reflected_i0) * avg_Rr; //from paper equation 50
        //normalize
        if(avg_e_R0i > 0.0){
            sigma_r0i = sigma_r0i/avg_e_R0i;
        } else {
            sigma_r0i = 0.0;
        }
        if(avg_e_Ri0 > 0.0){
            sigma_ri0 = sigma_ri0/avg_e_Ri0;
        } else {
            sigma_ri0 = 0.0;
        }

        //save lobe statistics
        int lobeIndexOfLayer_i = i - 1;
        if(avg_r0i > 0.0) {
            lobes[lobeIndexOfLayer_i].energy = r0i;
            lobes[lobeIndexOfLayer_i].mean = cosTheta_I;
            //TODO: check why this equation
            lobes[lobeIndexOfLayer_i].variance = (sigma_transmitted_i0 + sigma_transmitted_0i + Ji0 * (sigma_reflected_12 + avg_Rr * sigma_reflected_i0));
        } else {
            lobes[lobeIndexOfLayer_i].energy = vec3(0.0);
            lobes[lobeIndexOfLayer_i].mean = cosTheta_I;
            lobes[lobeIndexOfLayer_i].variance = 0.0;
        }

        //update variables for next iteration
        cosTheta_I = cosTheta_T;
        energy_reflected_0i = e_R0i;
        energy_reflected_i0 = e_Ri0;
        energy_transmitted_0i = t0i;
        energy_transmitted_i0 = ti0;
        sigma_reflected_0i = sigma_r0i;
        sigma_reflected_i0 = sigma_ri0;
        sigma_transmitted_0i = sigma_t0i;
        sigma_transmitted_i0 = sigma_ti0;
        J0i *= J12; //from supplemental code layered_forward.cpp line 256
        Ji0 *= J21; //from supplemental code layered_forward.cpp line 257

        //early return if conductor
        if(!isZero(kappaT)){
            valid_lobes = uint(i);
            return;
        }
    }

    valid_lobes = layerCount;
}

/////////// main ///////////

void main() {

    if(uLayerCount == 0u){
        fragColor = vec3(0.0);
        return;
    }

    // N is the surface normal in world space
    vec3 N = normalize(n);
    // L is the light direction in world spacegit 
    vec3 L = normalize(uLightDir);
    // V is the view direction in world space
    vec3 V = normalize(uCameraPosition - worldPos);
    // H is the half vector between L and V
    vec3 H = normalize(V + L);

    float cosThetaI = max(dot(N, L), 0.0);

    BsdfLobe lobes[MAX_LAYERS]; 
    uint valid_lobes = 0u;

    vec3 layerEta[LAYER_ARRAY_SIZE];
    vec3 layerKappa[LAYER_ARRAY_SIZE];
    float layerAlpha[LAYER_ARRAY_SIZE];
    float layerDepth[LAYER_ARRAY_SIZE];
    vec3 layerSigmaA[LAYER_ARRAY_SIZE];
    vec3 layerSigmaS[LAYER_ARRAY_SIZE];
    float layerG[LAYER_ARRAY_SIZE];

    fillLayerMaterialArrays(uLayerCount, layerEta, layerKappa, layerAlpha, layerDepth, layerSigmaA, layerSigmaS, layerG);

    addingDoubling(N, L, V, cosThetaI, uLayerCount, layerEta, layerKappa, layerAlpha, layerDepth, layerSigmaA, layerSigmaS, layerG, lobes, valid_lobes);
 
    //eval LayeredBRDF
    vec3 BRDF = vec3(0.0);
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float NdotH = max(dot(N, H), 0.0);
    float HdotV = max(dot(H, V), 0.0);
    float debug_D[MAX_LAYERS];
    float debug_G[MAX_LAYERS];

    for(int i = 0; i < int(valid_lobes); i++){
        float alpha = varianceToRoughness(lobes[i].variance);
        // Remap roughness
        float k = k_direct(alpha);

        float G =  G_smith_ggx(NdotV, NdotL, k);
        float D = D_ggx(NdotH, alpha);

        BRDF += (lobes[i].energy * D * G) / (4.0 * NdotL * NdotV + 0.0001);

        debug_D[i] = D;
        debug_G[i] = G;
    }

    vec3 lighting = BRDF * uLightColor * NdotL;

    RENDER_VIEW(lighting);
    DEBUG_VIEW(1, BRDF);

    DEBUG_VIEW(2, lobes[0].energy);
    DEBUG_VIEW(3, vec3(debug_D[0]));
    DEBUG_VIEW(4, vec3(debug_G[0]));
    DEBUG_VIEW(5, vec3(layerAlpha[1]);)
    DEBUG_VIEW(6, vec3(varianceToRoughness(lobes[0].variance)));

    if(valid_lobes > 1u){
        DEBUG_VIEW(7, lobes[1].energy);
        DEBUG_VIEW(8, vec3(debug_D[1]));
        DEBUG_VIEW(9, vec3(debug_G[1]));
        DEBUG_VIEW(10, vec3(layerAlpha[2]));
        DEBUG_VIEW(11, vec3(varianceToRoughness(lobes[1].variance)));
    }

    if(valid_lobes > 2u){
        DEBUG_VIEW(12, lobes[2].energy);
        DEBUG_VIEW(13, vec3(debug_D[2]));
        DEBUG_VIEW(14, vec3(debug_G[2]));
        DEBUG_VIEW(15, vec3(layerAlpha[3]));
        DEBUG_VIEW(16, vec3(varianceToRoughness(lobes[2].variance)));
    }


    //DEBUG F 
    vec3 etaI = layerEta[0];
    vec3 kappaI = layerKappa[0];
    vec3 etaT = layerEta[1];
    vec3 kappaT = layerKappa[1];
    vec3 F = evalFresnel(cosThetaI, etaI, kappaI, etaT, kappaT);
    DEBUG_VIEW(17, F);

    etaI = layerEta[1];
    kappaI = layerKappa[1];
    etaT = layerEta[2];
    kappaT = layerKappa[2];
    F = evalFresnel(cosThetaI, etaI, kappaI, etaT, kappaT);
    DEBUG_VIEW(18, F);

    etaI = layerEta[2];
    kappaI = layerKappa[2];
    etaT = layerEta[3];
    kappaT = layerKappa[3];
    F = evalFresnel(cosThetaI, etaI, kappaI, etaT, kappaT);
    DEBUG_VIEW(19, F);

    // nan/inf check
    DEBUG_VIEW(20, colorDebug(debugX));

}