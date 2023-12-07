#pragma once

#include <glm/glm.hpp>
#include <nlohmann/json.hpp>

#include <string>
#include <vector>

#include "config.hpp"
#include "gl/mesh.hpp"
#include "gl/program.hpp"
#include "gl/uniformbuffer.hpp"
#include "material.hpp"

class Object {
   public:
    Object();
    void loadPreset(nlohmann::json preset);
    void render(std::vector<Mesh>& meshes, std::vector<Program>& shaders, UniformBuffer<UB1>& ub1, const glm::mat4& projViewMat, float time);

    NLOHMANN_DEFINE_TYPE_INTRUSIVE(Object, name, meshIdx, shaderIdx, material, rotate, translation, rotation, scale);

    unsigned int id;
    std::string name = "Object";
    unsigned int meshIdx = 0;
    Config::ShaderType shaderIdx = Config::ShaderType::DEBUG;
    UB1 material = UB1{.layerCount = 0, .layerEta={glm::vec3(0.0)}, .layerKappa={glm::vec3(0.0)}, .layerAlpha{0.0}, .layerDepth{0.0}, .layerSigmaA{0.0}, .layerSigmaS{0.0}, .layerG{0.0}};
    bool rotate = false;
    glm::vec3 translation = glm::vec3(0.0f);
    glm::vec3 rotation = glm::vec3(0.0f);
    float scale = 1.0f;
};