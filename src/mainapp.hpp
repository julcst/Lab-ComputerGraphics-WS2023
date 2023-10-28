#pragma once

#include "framework/app.hpp"
#include "framework/camera.hpp"
#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"
#include "framework/gl/uniformbuffer.hpp"

class MainApp : public App {
   public:
    struct Uniforms {
        vec3 lightDir;
        float aspectRatio;
        vec3 skyColor;
        float focalLength;
        mat4 cameraRotation;
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
    UniformBuffer<Uniforms> ubo;
    Mesh fullscreenTriangle;
    Program backgroundShader;
    Mesh mesh;
    Program meshShader;
    GLuint lMVP;
};