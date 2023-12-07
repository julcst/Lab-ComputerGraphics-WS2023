#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
in vec3 worldPos;
out vec3 fragColor;

#define MAX_LAYERS 4

#include "uniforms.glsl"

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

float getLayerSigmaA(int layerIndex){
    return uLayerSigmaA[layerIndex/4][layerIndex%4];
}

float getLayerSigmaS(int layerIndex){
    return uLayerSigmaS[layerIndex/4][layerIndex%4];
}

float getLayerG(int layerIndex){
    return uLayerG[layerIndex/4][layerIndex%4];
}


/////////// main ///////////

void main() {
   
    // N is the surface normal in world space
    vec3 N = normalize(n);
    // L is the light direction in world spacegit 
    vec3 L = uLightDir;
    // V is the view direction in world space
    vec3 V = normalize(uCameraPosition - worldPos);

    float cosThetaI = max(dot(N, L), 0.0);

    //BsdfLobe lobes[MAX_LAYERS]; 
    //uint valid_lobes = 0;

    //addingDoubling(N, L, V, cosThetaI, uLayerCount, uLayerIOR, uLayerAlpha, uLayerDepth, uLayerSigmaA, uLayerSigmaS, uLayerG, lobes, valid_lobes);
 
    //eval LayeredBSDF
    //for(uint i = 0; i < valid_lobes; i++){
    //    if(lobes[i].energy == 0.0){
    //        continue;
    //    }  
    //    ...
    //}

    //TODO: replace with actual layered brdf
    fragColor = getLayerEta(0) * uLightColor * cosThetaI;
}