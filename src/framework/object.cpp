#include "object.hpp"
#include "common.hpp"
#include <json.hpp>

#include <filesystem>
#include <string>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <imgui.h>

using namespace glm;
using json = nlohmann::json;

Object::Object(std::vector<Mesh>& meshes, int mesh, int shader, int id) {
    meshIdx = mesh;
    shaderIdx = shader;
    translation = vec3(0.0f,0.0f,0.0f);

    ub1_data.albedo = vec3(0.8f);

    std::filesystem::path meshPath(meshes[meshIdx].getFilepath());
    name = std::to_string(id) + " - " + meshPath.stem().string();
}

void Object::render(std::vector<Mesh>& meshes, std::vector<Program>& shaders, UniformBuffer<UB1>& ub1, mat4 projMat, mat4 viewMat, float time) {
    mat4 modelMat = rotation ? rotate(mat4(1.0f), time, vec3(0.0f, 1.0f, 0.0f)) : mat4(1.0f);
    mat4 translMat = translate(mat4(1.0f), translation);
    modelMat = translMat * modelMat;

    ub1_data.model = modelMat;
    ub1_data.MVP = projMat * viewMat * modelMat;
    ub1.uniforms = ub1_data;
    ub1.upload();
    
    shaders[shaderIdx].bind();
    meshes[meshIdx].draw();
}

void Object::buildImGui() {
    ImGui::Begin(name.c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::ColorEdit3("Albedo", value_ptr(ub1_data.albedo), ImGuiColorEditFlags_Float);
    ImGui::SliderFloat("Roughness", &ub1_data.roughness, 0.0f, 1.0f);
    ImGui::SliderFloat("Metallic", &ub1_data.metallic, 0.0f, 1.0f);
    ImGui::Checkbox("Rotate Mesh", &rotation);
    ImGui::SliderFloat3("Translation", (float*)&translation, -50.0f, 50.0f);
    ImGui::End();
}