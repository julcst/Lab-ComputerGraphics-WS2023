#include <iostream>

#include <config.hpp>

#include "mainapp.hpp"

int main() {
    try {
        MainApp app;
        app.loadScene(Config::SCENE_DIR + "autosave.json");
        app.run();
        std::cout << "Autosaving to " << Config::SCENE_DIR << std::endl;
        app.saveScene(Config::SCENE_DIR + "autosave.json");
    } catch (std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return -1;
    }
    return 0;
}