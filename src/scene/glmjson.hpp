#pragma once

#include <glm/glm.hpp>
#include <nlohmann/json.hpp>

namespace glm {

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(vec3, x, y, z);
NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(vec4, x, y, z, w);

}