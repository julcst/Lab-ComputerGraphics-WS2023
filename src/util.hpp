#pragma once

#include <glm/glm.hpp>

namespace Util {

void FPSWindow(float frametime, const glm::vec2& resolution);
bool sphericalSlider(const char* label, glm::vec3& cartesian);
bool angleSlider3(const char* label, glm::vec3& angles);

}