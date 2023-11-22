#pragma once

#include <glm/glm.hpp>
#include <nlohmann/json.hpp>

#include "framework/glmjson.hpp"

struct UB1 {
    glm::vec3 albedo = glm::vec3(1.0f);
    float roughness = 1.0f;
    float metallic = 0.0f;
    glm::vec3 padding = glm::vec3(0.0f);
    glm::mat4 MVP = glm::mat4(1.0f);
    glm::mat4 model = glm::mat4(1.0f);

    NLOHMANN_DEFINE_TYPE_INTRUSIVE(UB1, albedo, roughness, metallic);
};