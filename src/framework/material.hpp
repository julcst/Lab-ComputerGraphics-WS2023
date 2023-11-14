#pragma once

#include <glm/glm.hpp>

using namespace glm;

const int DEBUG_SHADER = 0;
const int LAMBERT_SHADER = 1;
const int GGX_SHADER = 2;
const int GLINT_SHADER = 3;
const int LAYER_SHADER = 4;

struct GGX_UB {
        vec3 albedo = vec3(1.0f);
        float roughness = 1.0f;
        float metallic = 0.0f;
        vec3 padding = vec3(0.0f);
        mat4 MVP = mat4(1.0f);
        mat4 model = mat4(1.0f);
};