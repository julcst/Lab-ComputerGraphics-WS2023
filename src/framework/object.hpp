#pragma once

#include <string>
#include <vector>
#include <glm/glm.hpp>

#include "gl/mesh.hpp"
#include "material.hpp"
#include "gl/program.hpp"
#include "gl/uniformbuffer.hpp"

class Object {
   public:
    Object(std::vector<Mesh>& meshes, int mesh, int shader, int id);
    void render(std::vector<Mesh>& meshes, std::vector<Program>& shaders, UniformBuffer<UB1>& ub1, mat4 projMat, mat4 viewMat, float time);
    void buildImGui();

   private:
    int id;
    std::string name;
    int meshIdx;
    int shaderIdx;
    UB1 ub1_data;
    bool rotation = false;
    vec3 translation;
};