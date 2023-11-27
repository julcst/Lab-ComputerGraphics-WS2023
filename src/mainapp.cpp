#include "mainapp.hpp"

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <imgui.h>
#include <misc/cpp/imgui_stdlib.h>
#include <nlohmann/json.hpp>

#include <iterator>
#include <string>
#include <vector>

#include "config.hpp"
#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"
#include "framework/common.hpp"
#include "util.hpp"

using namespace glm;
using json = nlohmann::json;

const unsigned int WIDTH = 800;
const unsigned int HEIGHT = 600;
const float NEAR = 0.1f;
const float FAR = 100.0f;
const float FOV = 45.0f;
const float FOCAL_LENGTH = 4.0f / tan(FOV);

MainApp::MainApp() :
    App(WIDTH, HEIGHT),
    cam(0.0f, 0.0f, 5.0f, 3.0f, 50.0f),
    ub0(0, UB0{.lightDir = normalize(vec3(1.0f)), .skyColor = vec3(0.1f, 0.3f, 0.6f), .focalLength = FOCAL_LENGTH}),
    ub1(1, UB1{.albedo = vec3(0.8f)}) {

    fullscreenTriangle.load(FULLSCREEN_VERTICES, FULLSCREEN_INDICES);
    backgroundShader.load("screen.vert", "background.frag");
    backgroundShader.bindUBO("UB0", 0);
    backgroundShader.bindUBO("UB1", 1);

    meshes.reserve(Config::MODEL_FILES.size());
    for (const std::string& file : Config::MODEL_FILES) {
        Mesh mesh;
        mesh.load(file);
        meshes.push_back(std::move(mesh));
    }

    shaders.reserve(Config::SHADER_FILES.size());
    for (const std::string& file : Config::SHADER_FILES) {
        Program program;
        program.load("projection.vert", file);
        program.bindUBO("UB0", 0);
        program.bindUBO("UB1", 1);
        shaders.push_back(std::move(program));
    }
}

void MainApp::init() {
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glHint(GL_FRAGMENT_SHADER_DERIVATIVE_HINT, GL_NICEST);
    glCullFace(GL_BACK);
}

void MainApp::render() {
    mat4 projMat = perspective(FOV, resolution.x / resolution.y, NEAR, FAR);
    mat4 viewMat = cam.calcView();
    mat4 projViewMat = projMat * viewMat;

    ub0.uniforms.aspectRatio = resolution.x / resolution.y;
    ub0.uniforms.cameraRotation = mat4(cam.calcRotation());
    ub0.uniforms.cameraPosition = cam.getPosition();
    ub0.upload();

    glClear(GL_DEPTH_BUFFER_BIT);

    glDepthMask(GL_FALSE);
    backgroundShader.bind();
    fullscreenTriangle.draw();

    glDepthMask(GL_TRUE);

    for (Object& obj : objects) {
        obj.render(meshes, shaders, ub1, projViewMat, time);
    }
}

void MainApp::keyCallback(Key key, Action action) {
    if (key == Key::ESC && action == Action::PRESS) close();
}

void MainApp::scrollCallback(float amount) {
    cam.zoom(amount);
}

void MainApp::moveCallback(const vec2& movement, bool leftButton, bool rightButton, bool middleButton) {
    if (rightButton) cam.rotate(movement * 0.01f);
}

void MainApp::buildImGui() {
    Util::FPSWindow(delta, resolution);

    ImGui::SetNextWindowPos(ImVec2(0, 50), ImGuiCond_Once);
    ImGui::Begin("Scene", NULL, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::ColorEdit3("Sky Color", value_ptr(ub0.uniforms.skyColor), ImGuiColorEditFlags_Float);
    ImGui::SliderFloat("Fake Ambient Strength", &ub0.uniforms.ambientStrength, 0.0f, 1.0f);
    ImGui::ColorEdit3("Light Color", value_ptr(ub0.uniforms.lightColor), ImGuiColorEditFlags_Float | ImGuiColorEditFlags_HDR);
    Util::sphericalSlider("Light Direction", ub0.uniforms.lightDir);
    ImGui::Separator();
    ImGui::InputText("Scene Path", &scenePath);
    if (ImGui::Button("Load Scene")) loadScene(scenePath);
    ImGui::SameLine();
    if (ImGui::Button("Save Scene")) saveScene(scenePath);
    ImGui::SameLine();
    if (ImGui::Button("Clear")) objects.clear();
    ImGui::Separator();
    if (ImGui::Button("Add Object")) {
        Object newObject;
        objects.push_back(std::move(newObject));
    }
    ImGui::End();

    // Draw Object GUIs
    for (auto it = objects.rbegin(); it != objects.rend(); ++it) {
        Object& obj = *it;

        std::string windowName = obj.name + "###" + std::to_string(obj.id);
        ImGui::Begin(windowName.c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize);
        ImGui::InputText("Name", &obj.name);
        int presetID = -1;
        if (Util::combo("Preset", &presetID, Config::MATERIAL_FILES)) {
            std::string path = Config::MATERIAL_FILES[presetID];
            std::string raw = Common::readFile(path);
            json preset = json::parse(raw);
            obj.loadPreset(preset);
        }
        Util::combo("Shader", reinterpret_cast<int*>(&obj.shaderIdx), Config::SHADER_FILES);
        Util::combo("Mesh", &obj.meshIdx, Config::MODEL_FILES);
        ImGui::Separator();
        ImGui::Checkbox("Auto Rotate Mesh", &obj.rotate);
        Util::angleSlider3("Rotation", obj.rotation);
        ImGui::DragFloat3("Translation", value_ptr(obj.translation), 0.1f);
        ImGui::SliderFloat("Scale", &obj.scale, 0.1f, 10.0f);
        ImGui::Separator();
        if (obj.shaderIdx == Config::ShaderType::LAMBERT) {
            ImGui::ColorEdit3("Albedo", value_ptr(obj.material.albedo), ImGuiColorEditFlags_Float);
        } else if (obj.shaderIdx == Config::ShaderType::GGX) {
            ImGui::ColorEdit3("Albedo", value_ptr(obj.material.albedo), ImGuiColorEditFlags_Float);
            ImGui::SliderFloat("Roughness", &obj.material.roughness, 0.0f, 1.0f);
            ImGui::SliderFloat("Metallic", &obj.material.metallic, 0.0f, 1.0f);
        } else if (obj.shaderIdx == Config::ShaderType::GLINTS) {
            ImGui::ColorEdit3("Albedo", value_ptr(obj.material.albedo), ImGuiColorEditFlags_Float);
            ImGui::SliderFloat("Roughness", &obj.material.roughness, 0.0f, 1.0f);
            ImGui::SliderFloat("Metallic", &obj.material.metallic, 0.0f, 1.0f);
            ImGui::SliderFloat("Screen Space Scale", &obj.material.screenSpaceScale, 1.0f, 100000.0f);
            ImGui::SliderFloat("Log Microfacet Density", &obj.material.logMicrofacetDensity, -10.0f, 10.0f);
            ImGui::SliderFloat("Density Randomization", &obj.material.densityRandomization, 0.0f, 10.0f);
            ImGui::SliderFloat("Microfacet Roughness", &obj.material.microfacetRoughness, 0.001f, 1.0f);
        }
        ImGui::Separator();
        if (ImGui::Button("Destroy")) {
            objects.erase(std::next(it).base());
        }
        ImGui::End();

    }
}

void MainApp::saveScene(std::string path) {
    json jScene;
    for (const Object& obj : objects) {
        jScene["objects"].push_back(obj);
    }
    Common::writeToFile(jScene.dump(4), path);
}

void MainApp::loadScene(std::string path) {
    std::string rawscenejson = Common::readFile(path);
    json scenedata = json::parse(rawscenejson);

    objects.clear();
    if (scenedata.contains("objects")) {
        for (const auto& objdata : scenedata["objects"]) {
            Object obj = objdata.template get<Object>();
            objects.push_back(std::move(obj));
        }
    }
}