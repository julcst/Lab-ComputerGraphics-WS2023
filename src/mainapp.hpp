#pragma once

#include "framework/app.hpp"
#include "framework/camera.hpp"
#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"
#include "framework/gl/uniformbuffer.hpp"
#include "framework/object.hpp"
#include "framework/material.hpp"

class MainApp : public App {
   public:
    struct UB0 {
        vec3 lightDir = vec3(0.0f);
        float aspectRatio = 1.0f;
        vec3 skyColor = vec3(0.0f);
        float focalLength = 1.0f;
        vec3 lightColor = vec3(1.0f);
        float ambientStrength = 0.08f;
        vec3 cameraPosition = vec3(0.0f);
        float padding = 0.0f;
        mat4 cameraRotation = mat4(1.0f);
    };
    MainApp();

   protected:
    void init() override;
    void buildImGui() override;
    void render() override;
    void keyCallback(Key key, Action action) override;
    void scrollCallback(float amount) override;
    void moveCallback(const vec2& movement, bool leftButton, bool rightButton, bool middleButton) override;

   private:
    Camera cam;
    UniformBuffer<UB0> ub0;
    UniformBuffer<UB1> ub1;
    Mesh fullscreenTriangle;
    Program backgroundShader;
    std::vector<Object> objects;
    std::vector<Mesh> meshes;
    std::string meshOptions;
    int meshIdx = 0;
    std::vector<Program> shaders;
    std::string shaderOptions;
    int shaderIdx = 0;
    std::string materialOptions;
    int materialIdx = 0;
    char scenePath[512] = {"testscene.scene"};
    void saveScene(std::string path);
    void loadScene(std::string path);
};