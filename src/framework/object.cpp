#include "object.hpp"

#include <imgui.h>

#include <filesystem>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <nlohmann/json.hpp>
#include <string>

#include "common.hpp"
#include "config.hpp"
#include "util.hpp"

using json = nlohmann::json;

Object::Object(std::vector<Mesh>& meshes, int mesh, int preset, int id) : id(id), meshIdx(mesh), translation(0.0f), rotation(0.0f), scale(1.0f) {
    // name
    std::filesystem::path meshPath(meshes[meshIdx].getFilepath());
    name = std::to_string(id) + " - " + meshPath.stem().string();

    // material
    std::string materialPath = Config::MATERIAL_FILES[preset];
    std::string rawmaterialjson = Common::readFile(materialPath);
    json materialdata = json::parse(rawmaterialjson);
    if (materialdata.contains("shader")) {
        shaderIdx = static_cast<Config::ShaderType>(materialdata.value("shader", 0));
    } else {
        shaderIdx = Config::ShaderType::DEBUG;
    }

    if (shaderIdx == Config::ShaderType::LAMBERT) {
        if (materialdata.contains("albedo")) {
            material.albedo[0] = materialdata["albedo"][0];
            material.albedo[1] = materialdata["albedo"][1];
            material.albedo[2] = materialdata["albedo"][2];
        }
    } else if (shaderIdx == Config::ShaderType::GGX) {
        if (materialdata.contains("albedo")) {
            material.albedo[0] = materialdata["albedo"][0];
            material.albedo[1] = materialdata["albedo"][1];
            material.albedo[2] = materialdata["albedo"][2];
        }
        if (materialdata.contains("roughness")) {
            material.roughness = materialdata.value("roughness", 1.f);
        }
        if (materialdata.contains("metallic")) {
            material.metallic = materialdata.value("metallic", 0.f);
        }
    }
}

void Object::render(std::vector<Mesh>& meshes, std::vector<Program>& shaders, UniformBuffer<UB1>& ub1, const glm::mat4& projMat, const glm::mat4& viewMat, float time) {
    glm::mat4 modelMat(1.0f);
    modelMat = glm::translate(modelMat, translation);
    modelMat = glm::scale(modelMat, glm::vec3(scale));
    modelMat = glm::rotate(modelMat, rotation.x, glm::vec3(1.0f, 0.0f, 0.0f));
    float yangle = rotate ? rotation.y + time : rotation.y;
    modelMat = glm::rotate(modelMat, yangle, glm::vec3(0.0f, 1.0f, 0.0f));
    modelMat = glm::rotate(modelMat, rotation.z, glm::vec3(0.0f, 0.0f, 1.0f));

    material.model = modelMat;
    material.MVP = projMat * viewMat * modelMat;
    ub1.uniforms = material;
    ub1.upload();

    shaders[static_cast<int>(shaderIdx)].bind();
    meshes[meshIdx].draw();
}

void Object::buildImGui() {
    ImGui::Begin(name.c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::Checkbox("Auto Rotate Mesh", &rotate);
    Util::angleSlider3("Rotation", rotation);   
    ImGui::DragFloat3("Translation", glm::value_ptr(translation), 0.1f);
    ImGui::SliderFloat("Scale", &scale, 0.1f, 10.0f);
    ImGui::Separator();
    if (shaderIdx == Config::ShaderType::LAMBERT) {
        ImGui::ColorEdit3("Albedo", value_ptr(material.albedo), ImGuiColorEditFlags_Float);
    } else if (shaderIdx == Config::ShaderType::GGX) {
        ImGui::ColorEdit3("Albedo", value_ptr(material.albedo), ImGuiColorEditFlags_Float);
        ImGui::SliderFloat("Roughness", &material.roughness, 0.0f, 1.0f);
        ImGui::SliderFloat("Metallic", &material.metallic, 0.0f, 1.0f);
    }
    ImGui::End();
}