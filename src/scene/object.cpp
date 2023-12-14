#include "object.hpp"

#include <imgui.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <nlohmann/json.hpp>

#include <string>

#include "config.hpp"
#include "framework/common.hpp"
#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"
#include "framework/gl/uniformbuffer.hpp"
#include "scene/ub1.hpp"

using json = nlohmann::json;

Object::Object() {
    static unsigned int currID = 0;
    id = ++currID;
}

void Object::loadPreset(json preset) {
    shaderIdx = static_cast<Config::ShaderType>(preset.value("shader", shaderIdx));
    meshIdx = preset.value("mesh", meshIdx);
    material.albedo = preset.value("albedo", material.albedo);
    material.roughness = preset.value("roughness", material.roughness);
    material.metallic = preset.value("metallic", material.metallic);
    rotate = preset.value("rotate", rotate);
    translation = preset.value("translation", translation);
    rotation = preset.value("rotation", rotation);
    scale = preset.value("scale", scale);
}

void Object::render(std::vector<Mesh>& meshes, std::vector<Program>& shaders, UniformBuffer<UB1>& ub1, const glm::mat4& projViewMat, float time) {
    glm::mat4 modelMat(1.0f);
    modelMat = glm::translate(modelMat, translation);
    modelMat = glm::scale(modelMat, glm::vec3(scale));
    modelMat = glm::rotate(modelMat, rotation.x, glm::vec3(1.0f, 0.0f, 0.0f));
    float yangle = rotate ? rotation.y + time : rotation.y;
    modelMat = glm::rotate(modelMat, yangle, glm::vec3(0.0f, 1.0f, 0.0f));
    modelMat = glm::rotate(modelMat, rotation.z, glm::vec3(0.0f, 0.0f, 1.0f));

    material.model = modelMat;
    material.MVP = projViewMat * modelMat;
    ub1.upload(material);

    shaders[static_cast<int>(shaderIdx)].bind();
    meshes[meshIdx].draw();
}