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
    Object() = default;
    Object(std::vector<Mesh>& meshes, int mesh, int material, int id);
    void render(std::vector<Mesh>& meshes, std::vector<Program>& shaders, UniformBuffer<UB1>& ub1, const glm::mat4& projMat, const glm::mat4& viewMat, float time);
    void buildImGui();

    NLOHMANN_DEFINE_TYPE_INTRUSIVE(Object, id, name, meshIdx, shaderIdx, material, rotate, translation, rotation, scale);

   private:
    int id;
    std::string name;
    int meshIdx;
    Config::ShaderType shaderIdx;
    UB1 material;
    bool rotate = false;
    glm::vec3 translation;
    glm::vec3 rotation;
    float scale;
};