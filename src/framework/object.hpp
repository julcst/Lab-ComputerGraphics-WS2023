#pragma once

#include <glm/glm.hpp>
#include <nlohmann/json.hpp>

#include <string>
#include <vector>

#include "config.hpp"
#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"
#include "framework/gl/uniformbuffer.hpp"
#include "framework/material.hpp"

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
    UB1 material;
    bool rotate = false;
    glm::vec3 translation = glm::vec3(0.0f);
    glm::vec3 rotation = glm::vec3(0.0f);
    float scale = 1.0f;
};