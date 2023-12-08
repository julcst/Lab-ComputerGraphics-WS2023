#include <iostream>

#include "mainapp.hpp"

int main() {
    try {
        MainApp app;
        app.loadScene(Config::SCENE_DIR + "autosave.json");
        app.run();
        app.saveScene(Config::SCENE_DIR + "autosave.json");
    } catch (std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}