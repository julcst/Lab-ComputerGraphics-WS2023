#pragma once

#include "framework/app.hpp"
#include "framework/camera.hpp"
#include "framework/gl/mesh.hpp"
#include "framework/gl/program.hpp"
#include "framework/gl/uniformbuffer.hpp"
#include "scene/object.hpp"
#include "scene/ub0.hpp"
#include "scene/ub1.hpp"

class MainApp : public App {
   public:
    MainApp();
    bool saveScene(std::string path);
    bool loadScene(std::string path);

   protected:
    void init() override;
    void buildImGui() override;
    void render() override;
    void keyCallback(Key key, Action action) override;
    void scrollCallback(float amount) override;
    void moveCallback(const vec2& movement, bool leftButton, bool rightButton, bool middleButton) override;

   private:
    Camera cam;
    UB0 scene;
    UniformBuffer<UB0> ub0;
    UniformBuffer<UB1> ub1;
    Mesh fullscreenTriangle;
    Program backgroundShader;
    std::vector<Object> objects;
    std::vector<Mesh> meshes;
    std::vector<Program> shaders;
    std::string scenePath = "";
};