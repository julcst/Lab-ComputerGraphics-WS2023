#pragma once

#include <glm/glm.hpp>
#include <nlohmann/json.hpp>

#include "framework/glmjson.hpp"

struct UB1 {

// Location 0
    glm::vec3 albedo = glm::vec3(1.0f);
    float roughness = 1.0f;

// Location 1
    float metallic = 0.0f;
    float screenSpaceScale = 1.0f;
    float logMicrofacetDensity = 0.0f;
    /** 
     * From the paper:
     *    "R defines another probability of microfacets being reflecting or
     * non-reflecting for any half-vector. This parameter is ad-hoc and we
     * cannot completely link it to a physical quantity. However, in prac-
     * tice, it behaves close to a microfacet roughness parameter: low R
     * will reduce the amount of glints and increase their intensity"
     */
    float microfacetRoughness = 0.5f;

// Location 2
    float densityRandomization = 0.0f;
    unsigned int debug = 0;
    glm::vec2 padding = glm::vec2(0.0f);

// Location 3-6
    glm::mat4 MVP = glm::mat4(1.0f);

// Location 7-10
    glm::mat4 model = glm::mat4(1.0f);

    NLOHMANN_DEFINE_TYPE_INTRUSIVE(UB1, albedo, roughness, metallic, screenSpaceScale, logMicrofacetDensity, microfacetRoughness, densityRandomization);
};