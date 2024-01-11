#pragma once

#include <glm/glm.hpp>
#include <nlohmann/json.hpp>

#include "glmjson.hpp"

struct UB1 {

// Location 0
    glm::vec3 albedo = glm::vec3(1.0f);
    float roughness = 1.0f;

// Location 1
    float metallic = 0.0f;
    float screenSpaceScale = 1.5f;
    float logMicrofacetDensity = 0.0f;
    /** 
     * From the paper:
     *    "R defines another probability of microfacets being reflecting or
     * non-reflecting for any half-vector. This parameter is ad-hoc and we
     * cannot completely link it to a physical quantity. However, in prac-
     * tice, it behaves close to a microfacet roughness parameter: low R
     * will reduce the amount of glints and increase their intensity"
     */
    float microfacetRoughness = 1.0f;

// Location 2
    float densityRandomization = 0.0f;
    unsigned int debug = 0;
    float alphaX = 0.0f; //Anisotropic Roughness
    float alphaY = 0.0f; //Anisotropic Roughness

// Location 3-6
    glm::mat4 MVP = glm::mat4(1.0f);

// Location 7-10
    glm::mat4 model = glm::mat4(1.0f);

// Location 11
    unsigned int layerCount = 0;
    glm::vec3 padding2 = glm::vec3(0.0f);

// Location 12-...
    glm::vec4 layerEta[Config::MAX_LAYERS];
    glm::vec4 layerKappa[Config::MAX_LAYERS];
    float layerAlpha[Config::MAX_LAYERS];
    float layerDepth[Config::MAX_LAYERS];
    glm::vec4 layerSigmaA[Config::MAX_LAYERS];
    glm::vec4 layerSigmaS[Config::MAX_LAYERS];
    float layerG[Config::MAX_LAYERS];

    NLOHMANN_DEFINE_TYPE_INTRUSIVE(UB1, albedo, roughness, metallic, screenSpaceScale, logMicrofacetDensity, microfacetRoughness, densityRandomization, alphaX, alphaY, layerCount, layerEta, layerKappa, layerAlpha, layerDepth, layerSigmaA, layerSigmaS, layerG, debug);
};