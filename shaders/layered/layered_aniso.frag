#version 330 core
#line 3 303

in VertexData {
    vec2 uv;
    vec3 worldPosition;
    vec3 worldNormal;
    vec3 worldTangent;
};
out vec3 fragColor;

float debugX = 0.0;

#include "layered/common.glsl"
#include "shared/uniforms.glsl"
#include "shared/debug.glsl"
#include "shared/tangentspace.glsl"
#include "shared/lowdiscrepancysequence.glsl"

/*
* Implementation of
* [1] Belcour, Laurent. "Efficient rendering of layered materials using an atomic decomposition with statistical operators." ACM Transactions on Graphics 37.4 (2018): 1.
* and
* [2] Weier, Philippe, and Laurent Belcour. "Rendering layered materials with anisotropic interfaces." Journal of Computer Graphics Techniques (JCGT) 9.2 (2020): 20.
*/

/////////// helper functions ///////////

int getLayerUseEtaTexture(int layerIndex){
    return uLayerUseEtaTexture[layerIndex/4][layerIndex%4];
}

int getLayerUseKappaTexture(int layerIndex){
    return uLayerUseKappaTexture[layerIndex/4][layerIndex%4];
}

int getLayerUseAlphaTexture(int layerIndex){
    return uLayerUseAlphaTexture[layerIndex/4][layerIndex%4];
}

vec3 getLayerEta(int layerIndex, vec2 texCoords){
    if(getLayerUseEtaTexture(layerIndex) == 1){
        return texture(textureLayerEta, vec3(texCoords, layerIndex)).rgb;
    } else {
        return uLayerEta[layerIndex].xyz;
    }
}

vec3 getLayerKappa(int layerIndex, vec2 texCoords){
    if(getLayerUseKappaTexture(layerIndex) == 1){
        return texture(textureLayerKappa, vec3(texCoords, layerIndex)).rgb;
    } else {
        return uLayerKappa[layerIndex].xyz;
    }
}

vec2 getLayerAlpha(int layerIndex, vec2 texCoords){
    if(getLayerUseAlphaTexture(layerIndex) == 1){
        return texture(textureLayerAlpha, vec3(texCoords, layerIndex)).rg;
    } else {
        return vec2(uLayerAlphaX[layerIndex/4][layerIndex%4], uLayerAlphaY[layerIndex/4][layerIndex%4]);
    }
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

void fillLayerMaterialArrays(vec2 texCoords, uint _layerCount, out vec3 _layerEta[MAX_LAYERS + 1], out vec3 _layerKappa[MAX_LAYERS + 1], out vec2 _layerAlpha[MAX_LAYERS + 1], out float _layerDepth[MAX_LAYERS + 1], out vec3 _layerSigmaA[MAX_LAYERS + 1], out vec3 _layerSigmaS[MAX_LAYERS + 1], out float _layerG[MAX_LAYERS + 1]){
    //air layer
    _layerEta[0] = vec3(1.0);
    _layerKappa[0] = vec3(0.0);
    _layerAlpha[0] = vec2(0.0);
    _layerDepth[0] = 0.0;
    _layerSigmaA[0] = vec3(0.0);
    _layerSigmaS[0] = vec3(0.0);
    _layerG[0] = 0.0;
    //fill with data from uniforms or textures
    //TODO: texture lookup
    for(int i = 0; i < int(_layerCount); i++) {
        _layerEta[i+1] = getLayerEta(i, texCoords);
        _layerKappa[i+1] = getLayerKappa(i, texCoords);
        _layerAlpha[i+1] = clamp(getLayerAlpha(i, texCoords), 0.0001, 1);
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
 * 
 */
struct BsdfLobe {
    vec3 energy; //e
    float mean; //mu
    vec2 variance; //sigma
};

/**
 * Adding Doubling Algorithm
 * section 5 of the paper [1]
 * implementation without doubling
 *
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
void addingDoubling(float cosThetaI, uint layerCount, vec3 layerEta[MAX_LAYERS + 1], vec3 layerKappa[MAX_LAYERS + 1], vec2 layerAlpha[MAX_LAYERS + 1], float layerDepth[MAX_LAYERS + 1], vec3 layerSigmaA[MAX_LAYERS + 1], vec3 layerSigmaS[MAX_LAYERS + 1], float layerG[MAX_LAYERS + 1], out BsdfLobe lobes[MAX_LAYERS], out uint valid_lobes){
    valid_lobes = 0u;
    
    float cosTheta_I = cosThetaI; //incident
    float cosTheta_T; //transmitted

    //start values for global variables (from paper [1] page 8 paragraph Adding-Doubling)
    // 0 = top surface / stack of layers to layer i  |  i = current layer
    //energy
    vec3 energy_reflected_0i = vec3(0.0);
    vec3 energy_reflected_i0 = vec3(0.0);
    vec3 energy_transmitted_0i = vec3(1.0);
    vec3 energy_transmitted_i0 = vec3(1.0);
    //variance
    vec2 sigma_reflected_0i = vec2(0.0);
    vec2 sigma_reflected_i0 = vec2(0.0);
    vec2 sigma_transmitted_0i = vec2(0.0);
    vec2 sigma_transmitted_i0 = vec2(0.0);
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
        vec2 alpha = layerAlpha[i];
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
        vec2 sigma_reflected_12 = vec2(0.0);
        vec2 sigma_reflected_21 = vec2(0.0);
        vec2 sigma_transmitted_12 = vec2(0.0);
        vec2 sigma_transmitted_21 = vec2(0.0);
        //scaling factors
        float J12 = 1.0;
        float J21 = 1.0;

        //TODO implement doubling

        //check if thin slab/interface or participating media/vloume
        if(depth > 0.0){
            //mean doesn't change
            cosTheta_T = cosTheta_I;

            /* volume absorption and scattering, from the paper [1] Section 4.3 and 4.4*/
            //energy
            vec3 sigma_t = sigma_a + sigma_s;
            energy_transmitted_12 = (vec3(1.0) + (sigma_s * depth) / cosTheta_T) * exp(-(sigma_t * depth) / cosTheta_T); //from paper [1], equation 15 and 22
            energy_transmitted_21 = energy_transmitted_12;
            //variance
            sigma_transmitted_12 = vec2(gToVariance(g) * average(sigma_s)/average(sigma_t)); //from paper [1], equation 24
            sigma_transmitted_21 = sigma_transmitted_12;
        }else{
            /* off-specular transmission, from the paper [1] Section 4.2 */
            float sinTheta_I = sqrt(1.0 - pow(cosTheta_I,2));
            float sinTheta_T = sinTheta_I / n12;
            if(sinTheta_T <= 1.0){
                cosTheta_T = sqrt(1.0 - pow(sinTheta_T,2));
            }else{
                cosTheta_T = -1.0;
            }

            /* reflectance and transmittance terms for variance */
            sigma_reflected_12 = roughnessToVariance(alpha); //from paper [1] section 4.1
            sigma_reflected_21 = sigma_reflected_12;

            //transmissive if not a conductor or total reflection
            bool transmissive = cosTheta_T > 0.0 && isZero(kappaT);
            if(transmissive){
                //from paper [1] section 4.3, equation 13
                //TODO: check if equation from paper [1] or equation from supplemental code works better
                sigma_transmitted_12 = roughnessToVariance(alpha * s(n12, cosTheta_I, cosTheta_T));
                sigma_transmitted_21 = roughnessToVariance(alpha * s(1.0/n12, cosTheta_T, cosTheta_I));
                
                //sigma_transmitted_12 = roughnessToVariance(alpha * 0.5f * abs(n12 - 1.0)/(n12));
                //sigma_transmitted_21 = roughnessToVariance(alpha * 0.5f * abs(1.0/n12 - 1.0)/(1.0/n12));
                
                //from paper [1] supplemental code, layered_forward.cpp line 171
                J12 = (cosTheta_T/cosTheta_I) * n12;
                J21 = (cosTheta_I/cosTheta_T) / n12;
            }

            /* reflectance and transmittance terms for energy */
            //evaluate FGD using modified roughness accounting for top layers
            vec2 alpha_r = varianceToRoughness(sigma_transmitted_0i + sigma_reflected_12); //from paper [1] section 4.1, equation 9
            //vec3 FGD = evalFGD(N, L, V, alpha_r, etaI, kappaI, etaT, kappaT); //from paper [1] section 4.1, equation 2
            vec3 FGD = evalFresnel(cosTheta_I, etaI, kappaI, etaT, kappaT); //TODO: check if FDG or just F
            energy_reflected_12 = FGD; //from paper [1] section 4.1, equation 7 / section 5.1
            energy_transmitted_12 = 1.0 - FGD; //from paper [1] section 4.2, equation 11 / section 5.1
            if(transmissive){
                energy_reflected_21 = energy_reflected_12; //from paper [1] section 5.1
                energy_transmitted_21 = energy_transmitted_12; //from paper [1] section 5.1
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
            r0i = (energy_transmitted_0i * energy_reflected_12 * energy_transmitted_i0) / denom; //from paper [1] section 5.1, equation 28
            ri0 = (energy_transmitted_21 * energy_reflected_i0 * energy_transmitted_12) / denom; //from paper [1] section 5.1, equation 30
            t0i = (energy_transmitted_0i * energy_transmitted_12) / denom; //from paper [1] section 5.1, equation 31
            ti0 = (energy_transmitted_21 * energy_transmitted_i0) / denom; //from paper [1] section 5.1, equation 29
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
        vec2 sigma_r0i = avg_energy_reflected_0i * sigma_reflected_0i + avg_r0i * (sigma_transmitted_i0 + sigma_transmitted_0i + Ji0 * (sigma_reflected_12 + avg_Rr * sigma_reflected_i0)); //from paper [1] equation 38
        vec2 sigma_t0i = J12 * sigma_transmitted_0i + sigma_transmitted_12 + J12 * (sigma_reflected_12 + sigma_reflected_i0) * avg_Rr; //from paper [1] equation 49
        vec2 sigma_ri0 = avg_energy_reflected_21 * sigma_reflected_21 + avg_ri0 * (sigma_transmitted_12 + J12 * (sigma_transmitted_21 + sigma_reflected_i0 + avg_Rr * (sigma_reflected_12 + sigma_reflected_i0))); //from paper [1] equation 51
        vec2 sigma_ti0 = Ji0 * sigma_transmitted_21 + sigma_transmitted_i0 + Ji0 * (sigma_reflected_12 + sigma_reflected_i0) * avg_Rr; //from paper [1] equation 50
        //normalize
        if(avg_e_R0i > 0.0){
            sigma_r0i = sigma_r0i/avg_e_R0i;
        } else {
            sigma_r0i = vec2(0.0);
        }
        if(avg_e_Ri0 > 0.0){
            sigma_ri0 = sigma_ri0/avg_e_Ri0;
        } else {
            sigma_ri0 = vec2(0.0);
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
            lobes[lobeIndexOfLayer_i].variance = vec2(0.0);
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

    mat3 worldToTangent = calcWorldToTangentMatrix(worldNormal, worldTangent);

    // Normal vector in world space
    vec3 N_world = worldNormal;
    // Normal vector in tangent space
    vec3 N_local = vec3(0.0, 0.0, 1.0);
    //View vector in world space
    vec3 V_world = normalize(uCameraPosition - worldPosition);
    // View vector in tangent space
    vec3 V_local = worldToTangent * V_world;
    // Light vector in world space
    vec3 L_world = uLightDir;
    // Light vector in tangent space
    vec3 L_local = worldToTangent * L_world;
    // H is the half vector between L and V
    vec3 H_world = normalize(V_world + L_world);
    vec3 H_local = normalize(V_local + L_local);

    BsdfLobe lobes[MAX_LAYERS]; 
    uint valid_lobes = 0u;

    vec3 layerEta[MAX_LAYERS + 1];
    vec3 layerKappa[MAX_LAYERS + 1];
    vec2 layerAlpha[MAX_LAYERS + 1];
    float layerDepth[MAX_LAYERS + 1];
    vec3 layerSigmaA[MAX_LAYERS + 1];
    vec3 layerSigmaS[MAX_LAYERS + 1];
    float layerG[MAX_LAYERS + 1];

    fillLayerMaterialArrays(uv, uLayerCount, layerEta, layerKappa, layerAlpha, layerDepth, layerSigmaA, layerSigmaS, layerG);

    //eval LayeredBRDF
    vec3 I = vec3(0.0);
    float debug_D[MAX_LAYERS];
    float debug_G[MAX_LAYERS];
    vec3 lighting = vec3(0.0);

    if(uUseCubemap){
        float cosThetaI = max(dot(N_local, V_local), 0.0);
        addingDoubling(cosThetaI, uLayerCount, layerEta, layerKappa, layerAlpha, layerDepth, layerSigmaA, layerSigmaS, layerG, lobes, valid_lobes);

        for(uint s = 0u; s < uIBLSampleCount; s++){
            vec2 U = hammersley(s, uIBLSampleCount);
            for(int i = 0; i < int(valid_lobes); i++){
                if(!isZero(lobes[i].energy)){
                    vec2 alpha = pow(varianceToRoughness(lobes[i].variance), vec2(2.0));

                    //implementation following Eric Heitz, Sampling the GGX Distribution of Visible Normals, Journal of Computer Graphics Techniques (JCGT), vol. 7, no. 4, 1-13, 2018
                    H_local = sampleGGXVNDF(V_local, alpha.x, alpha.y, U.x, U.y);
                    L_local = normalize(2.0 * dot(V_local, H_local) * H_local - V_local);
                    L_world = transpose(worldToTangent) * L_local;


                    //eval mipmap level (implementation following https://learnopengl.com/PBR/IBL/Specular-IBL)
                    float D = D_ggx_aniso(H_local, alpha.x, alpha.y);
                    float pdf = (D * dot(N_local, H_local) / (4.0 * dot(H_local, V_local))) + 0.0001; 

                    ivec2 resolution = textureSize(cubemap, 0); // resolution of source cubemap (per face)
                    float saTexel  = 4.0 * PI / (6.0 * resolution.x * resolution.y);
                    float saSample = 1.0 / (float(uIBLSampleCount) * pdf + 0.0001);

                    float mipLevel = 0.5 * log2(saSample / saTexel) + 1.0; 

                    vec3 lightSample = textureLod(cubemap, L_world, mipLevel).rgb;

                    I += lightSample * ((lobes[i].energy * G2_ggx_aniso(V_local, L_local, alpha.x, alpha.y)) / G1_ggx_aniso(V_local, alpha.x, alpha.y));
                }
            }
        }

        lighting = (I/uIBLSampleCount);
    } else {
        float NdotV = max(dot(N_local, V_local), 0.0);
        float NdotL = max(dot(N_local, L_local), 0.0);
        float HdotL = max(dot(H_local, L_local), 0.0);
        addingDoubling(NdotV, uLayerCount, layerEta, layerKappa, layerAlpha, layerDepth, layerSigmaA, layerSigmaS, layerG, lobes, valid_lobes);
        
        for(int i = 0; i < int(valid_lobes); i++){
            if(!isZero(lobes[i].energy)){
                vec2 alpha = pow(varianceToRoughness(lobes[i].variance), vec2(2.0));
                
                float G =  G2_ggx_aniso(V_local, L_local, alpha.x, alpha.y);
                float D = D_ggx_aniso(H_local, alpha.x, alpha.y);

                I += (lobes[i].energy * D * G) / (4.0 * NdotL * NdotV + 0.0001);

                debug_D[i] = D;
                debug_G[i] = G;
            }
        }

        lighting = I * uLightColor * NdotL;
    }
    

    RENDER_VIEW(lighting);
    DEBUG_VIEW(1, I);

    DEBUG_VIEW(2, lobes[0].energy);
    DEBUG_VIEW(3, vec3(debug_D[0]));
    DEBUG_VIEW(4, vec3(debug_G[0]));
    DEBUG_VIEW(5, vec3(layerAlpha[1],0.0);)
    DEBUG_VIEW(6, vec3(varianceToRoughness(lobes[0].variance),0.0));

    if(valid_lobes > 1u){
        DEBUG_VIEW(7, lobes[1].energy);
        DEBUG_VIEW(8, vec3(debug_D[1]));
        DEBUG_VIEW(9, vec3(debug_G[1]));
        DEBUG_VIEW(10, vec3(layerAlpha[2],0.0));
        DEBUG_VIEW(11, vec3(varianceToRoughness(lobes[1].variance),0.0));
    }

    if(valid_lobes > 2u){
        DEBUG_VIEW(12, lobes[2].energy);
        DEBUG_VIEW(13, vec3(debug_D[2]));
        DEBUG_VIEW(14, vec3(debug_G[2]));
        DEBUG_VIEW(15, vec3(layerAlpha[3],0.0));
        DEBUG_VIEW(16, vec3(varianceToRoughness(lobes[2].variance),0.0));
    }


    //DEBUG F 
    float cosThetaI = max(dot(N_local, V_local), 0.0);
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