#pragma once

#include <string>
#include <glad/glad.h>
#include "framework/gl/program.hpp"
#include "config.hpp"

class Texture {
   public:
    Texture();
    Texture(GLenum textureUnit, int samplerID, std::string samplerName, GLenum format);
    void load(unsigned int layerIndex);
    void bind(Program& program);
    std::string path[Config::MAX_LAYERS];
   private:
    unsigned int textureID;
    GLenum textureUnit;
    int samplerID;
    std::string samplerName;
    bool loaded = false;
    int loadedWidth;
    int loadedHeight;
    GLenum format;
};