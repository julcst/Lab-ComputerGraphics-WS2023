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
    mat4 projMat = perspective(FOV, resolution.x / resolution.y, NEAR, FAR);
    mat4 viewMat = cam.calcView();

    ub0.uniforms.aspectRatio = resolution.x / resolution.y;
    ub0.uniforms.cameraRotation = mat4(cam.calcRotation());
    ub0.uniforms.cameraPosition = cam.getPosition();
    ub0.upload();

    glClear(GL_DEPTH_BUFFER_BIT);

    glDepthMask(GL_FALSE);
    backgroundShader.bind();
    fullscreenTriangle.draw();

    glDepthMask(GL_TRUE);

    for (int i = 0; i < objects.size(); i++){
        objects[i]->render(meshes, shaders, ub1, projMat, viewMat, time);
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

    ImGui::Begin("Settings", NULL, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::ColorEdit3("Sky Color", value_ptr(ub0.uniforms.skyColor), ImGuiColorEditFlags_Float);
    ImGui::SliderFloat("Fake Ambient Strength", &ub0.uniforms.ambientStrength, 0.0f, 1.0f);
    ImGui::ColorEdit3("Light Color", value_ptr(ub0.uniforms.lightColor), ImGuiColorEditFlags_Float | ImGuiColorEditFlags_HDR);
    Util::sphericalSlider("Light Direction", ub0.uniforms.lightDir);
    ImGui::Combo("Shader", &shaderIdx, shaderOptions.c_str());
    ImGui::Combo("Mesh", &meshIdx, meshOptions.c_str());
    if(ImGui::Button("Add Mesh to Scene")) {
        Object* newObject = new Object(meshes, meshIdx, shaderIdx, objects.size());
        objects.push_back(newObject);
    }
    ImGui::End();

    //Object GUIs
    for (int i = 0; i < objects.size(); i++){
        objects[i]->buildImGui();
    }
}

void MainApp::close() {
    for (int i = 0; i < objects.size(); i++){
        delete objects[i];
    }
    App::close();
}