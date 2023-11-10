#pragma once

#include <glm/glm.hpp>

using namespace glm;

struct UB1 {
        vec3 albedo = vec3(1.0f);
        float roughness = 1.0f;
        float metallic = 0.0f;
        vec3 padding = vec3(0.0f);
        mat4 MVP = mat4(1.0f);
        mat4 model = mat4(1.0f);
};