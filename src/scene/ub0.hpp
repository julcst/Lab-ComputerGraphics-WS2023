#pragma once

#include <glm/glm.hpp>
#include <nlohmann/json.hpp>

#include "glmjson.hpp"

struct UB0 {
    glm::vec3 lightDir = glm::vec3(0.0f);
    float aspectRatio = 1.0f;
    glm::vec3 skyColor = glm::vec3(0.0f);
    float focalLength = 1.0f;
    glm::vec3 lightColor = glm::vec3(1.0f);
    float ambientStrength = 0.08f;
    glm::vec3 cameraPosition = glm::vec3(0.0f);
    int useCubemap = 0;
    glm::mat4 cameraRotation = glm::mat4(1.0f);

    NLOHMANN_DEFINE_TYPE_INTRUSIVE(UB0, lightDir, skyColor, lightColor, ambientStrength);
};