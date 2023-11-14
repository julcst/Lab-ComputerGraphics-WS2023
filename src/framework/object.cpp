#include "object.hpp"
#include "../config.hpp"
#include "common.hpp"
#include <nlohmann/json.hpp>

#include <filesystem>
#include <string>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <imgui.h>

using namespace glm;
using json = nlohmann::json;

Object::Object(std::vector<Mesh>& meshes, int mesh, int material, int id) {
    meshIdx = mesh;
    translation = vec3(0.0f,0.0f,0.0f);
    rotation = vec3(0.0f,0.0f,0.0f);
    scaleFactor = 1.0f;
    
    //name
    std::filesystem::path meshPath(meshes[meshIdx].getFilepath());
    name = std::to_string(id) + " - " + meshPath.stem().string();

    //material
    std::string materialPath = Config::MATERIAL_FILES[material];
    std::string rawmaterialjson = Common::readFile(materialPath);
    json materialdata = json::parse(rawmaterialjson);
    if(materialdata.contains("shader")) {
        shaderIdx = materialdata.value("shader", 0);
    }else {
        shaderIdx = DEBUG_SHADER;
    }

    if(shaderIdx == LAMBERT_SHADER){
        if (materialdata.contains("albedo")) {
            ub1_data.albedo[0] = materialdata["albedo"][0];
            ub1_data.albedo[1] = materialdata["albedo"][1];
            ub1_data.albedo[2] = materialdata["albedo"][2];
        }
    } else if( shaderIdx == GGX_SHADER){
        if (materialdata.contains("albedo")) {
            ub1_data.albedo[0] = materialdata["albedo"][0];
            ub1_data.albedo[1] = materialdata["albedo"][1];
            ub1_data.albedo[2] = materialdata["albedo"][2];
        }
        if (materialdata.contains("roughness")) {
            ub1_data.roughness = materialdata.value("roughness", 1.f);
        }
        if (materialdata.contains("metallic")) {
            ub1_data.metallic = materialdata.value("metallic", 0.f);
        }
    }
}

void Object::render(std::vector<Mesh>& meshes, std::vector<Program>& shaders, UniformBuffer<GGX_UB>& ub1, mat4 projMat, mat4 viewMat, float time) {
    mat4 modelMat(1.0f);
    modelMat = translate(modelMat, translation);
    modelMat = scale(modelMat, vec3(scaleFactor));
    modelMat = auto_rotation ? rotate(modelMat, time, vec3(0.0f, 1.0f, 0.0f)) : modelMat;
    modelMat = rotate(modelMat, radians(rotation[0]), vec3(1.0f, 0.0f, 0.0f));
    modelMat = rotate(modelMat, radians(rotation[1]), vec3(0.0f, 1.0f, 0.0f));
    modelMat = rotate(modelMat, radians(rotation[2]), vec3(0.0f, 0.0f, 1.0f));

    ub1_data.model = modelMat;
    ub1_data.MVP = projMat * viewMat * modelMat;
    ub1.uniforms = ub1_data;
    ub1.upload();
    
    shaders[shaderIdx].bind();
    meshes[meshIdx].draw();
}

void Object::buildImGui() {
    ImGui::Begin(name.c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::Checkbox("Auto Rotate Mesh", &auto_rotation);
    ImGui::SliderFloat3("Rotation", (float*)&rotation, 0.0f, 360.0f);
    ImGui::SliderFloat3("Translation", (float*)&translation, -50.0f, 50.0f);
    ImGui::SliderFloat("Scale", &scaleFactor, 0.1f, 10.0f);
    ImGui::Separator();
    if(shaderIdx == LAMBERT_SHADER){
        ImGui::ColorEdit3("Albedo", value_ptr(ub1_data.albedo), ImGuiColorEditFlags_Float);
    }
    if(shaderIdx == GGX_SHADER){
        ImGui::ColorEdit3("Albedo", value_ptr(ub1_data.albedo), ImGuiColorEditFlags_Float);
        ImGui::SliderFloat("Roughness", &ub1_data.roughness, 0.0f, 1.0f);
        ImGui::SliderFloat("Metallic", &ub1_data.metallic, 0.0f, 1.0f);
    }
    ImGui::End();
}