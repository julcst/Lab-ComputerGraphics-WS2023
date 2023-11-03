#include "mainapp.hpp"

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <imgui.h>

#include <vector>

#include "config.hpp"
#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"
#include "util.hpp"

using namespace glm;

MainApp::MainApp() :
    App(800, 600),
    cam(0.0f, 0.0f, 5.0f, 3.0f, 50.0f),
    ub0(0, UB0{.lightDir = normalize(vec3(1.0f)), .skyColor = vec3(0.1f, 0.3f, 0.6f), .focalLength = 4.0f / tan(45.0f)}),
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
        meshOptions.append(file + '\0');
    }

    shaders.reserve(Config::SHADER_FILES.size());
    for (const std::string& file : Config::SHADER_FILES) {
        Program program;
        program.load("projection.vert", file);
        program.bindUBO("UB0", 0);
        program.bindUBO("UB1", 1);
        shaders.push_back(std::move(program));
        shaderOptions.append(file + '\0');
    }
}

void MainApp::init() {
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
}

void MainApp::render() {
    mat4 projMat = perspective(45.0f, resolution.x / resolution.y, 0.1f, 100.0f);
    mat4 viewMat = cam.calcView();
    mat4 modelMat = rotation ? rotate(mat4(1.0f), time, vec3(0.0f, 1.0f, 0.0f)) : mat4(1.0f);

    ub0.uniforms.aspectRatio = resolution.x / resolution.y;
    ub0.uniforms.cameraRotation = mat4(cam.calcRotation());
    ub0.upload();

    ub1.uniforms.model = modelMat;
    ub1.uniforms.MVP = projMat * viewMat * modelMat;
    ub1.upload();

    glClear(GL_DEPTH_BUFFER_BIT);

    glDepthMask(GL_FALSE);
    backgroundShader.bind();
    fullscreenTriangle.draw();

    glDepthMask(GL_TRUE);
    shaders[shaderIdx].bind();
    meshes[meshIdx].draw();
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

    ImGui::Begin("Settings", NULL, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::ColorEdit3("Sky Color", value_ptr(ub0.uniforms.skyColor));
    Util::sphericalSlider("Light Direction", ub0.uniforms.lightDir);
    ImGui::Checkbox("Rotate Mesh", &rotation);
    ImGui::Combo("Shader", &shaderIdx, shaderOptions.c_str());
    ImGui::Combo("Mesh", &meshIdx, meshOptions.c_str());
    ImGui::End();
}