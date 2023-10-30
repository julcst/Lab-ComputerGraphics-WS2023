#include "mainapp.hpp"

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <imgui.h>
#include <imgui_internal.h>

#include <vector>

#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"

using namespace glm;

// Cube mesh
const std::vector<float> vertices = {
    -1.0f, -1.0f,  1.0f, // 0
     1.0f, -1.0f,  1.0f, // 1
     1.0f,  1.0f,  1.0f, // 2
    -1.0f,  1.0f,  1.0f, // 3
    -1.0f, -1.0f, -1.0f, // 4
     1.0f, -1.0f, -1.0f, // 5
     1.0f,  1.0f, -1.0f, // 6
    -1.0f,  1.0f, -1.0f, // 7
};
const std::vector<unsigned int> indices = {
    0, 1, 2, 2, 3, 0,  // Front
    1, 5, 6, 6, 2, 1,  // Right
    7, 6, 5, 5, 4, 7,  // Back
    4, 0, 3, 3, 7, 4,  // Left
    4, 5, 1, 1, 0, 4,  // Bottom
    3, 2, 6, 6, 7, 3,  // Top
};

MainApp::MainApp() : App(800, 600), cam(0.0f, 0.0f, 5.0f, 3.0f, 50.0f), ubo(0, Uniforms{normalize(vec3(0.4f, 0.3f, 0.5f)), resolution.x / resolution.y, vec3(0.1f, 0.3f, 0.6f), 4.0f / tan(45.0f), mat4(cam.calcRotation())}) {
    fullscreenTriangle.load(FULLSCREEN_VERTICES, FULLSCREEN_INDICES);
    backgroundShader.load("screen.vert", "background.frag");
    backgroundShader.bindUBO("Uniforms", 0);

    mesh.load("sphere.obj");
    meshShader.load("projection.vert", "lighting.frag");
    lMVP = meshShader.uniform("uMVP");
}

void MainApp::init() {
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
}

void MainApp::render() {
    // Render the mesh in the foreground
    mat4 projMat = perspective(45.0f, resolution.x / resolution.y, 0.1f, 100.0f);
    mat4 viewMat = cam.calcView();
    mat4 modelMat = rotate(mat4(1.0f), 0.0f, vec3(0.0f, 1.0f, 0.0f));

    ubo.uniforms.aspectRatio = resolution.x / resolution.y;
    ubo.uniforms.cameraRotation = mat4(cam.calcRotation());
    ubo.upload();

    glClear(GL_DEPTH_BUFFER_BIT);

    glDepthMask(GL_FALSE);
    backgroundShader.bind();
    fullscreenTriangle.draw();

    glDepthMask(GL_TRUE);
    meshShader.bind();
    meshShader.set(lMVP, projMat * viewMat * modelMat);
    mesh.draw();
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

bool sphericalSlider(const char* label, vec3& cart) {
    vec2 sph = vec2(asin(cart.y), atan(cart.x, cart.z));
    ImGui::PushID(label);
    bool changed = false;
    ImGui::PushMultiItemsWidths(2, ImGui::CalcItemWidth());
    ImGui::PushID(0);
    changed |= ImGui::SliderAngle("", &sph.x, -89.0f, 89.0f);
    ImGui::PopItemWidth(); ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
    ImGui::PopID(); ImGui::PushID(1);
    changed |= ImGui::SliderAngle("", &sph.y);
    ImGui::PopItemWidth(); ImGui::SameLine(0.0f, ImGui::GetStyle().ItemInnerSpacing.x);
    ImGui::PopID();
    ImGui::TextUnformatted(label);
    ImGui::PopID();
    if (changed) cart = vec3(cos(sph.x) * sin(sph.y), sin(sph.x), cos(sph.x) * cos(sph.y));
    return changed;
}

void MainApp::buildImGui() {
    // Stat window
    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0.0f, 0.0f, 0.0f, 0.5f));
    ImGui::Begin("Statistics", NULL, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoInputs | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoSavedSettings);
    ImGui::Text("%2.1ffps avg: %2.1ffps %.0fx%.0f", 1.f / delta, ImGui::GetIO().Framerate, resolution.x, resolution.y);
    ImGui::PopStyleColor();
    ImGui::End();

    ImGui::Begin("Settings", NULL, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::ColorEdit3("Sky Color", value_ptr(ubo.uniforms.skyColor));
    sphericalSlider("Light Direction", ubo.uniforms.lightDir);
    ImGui::End();
}