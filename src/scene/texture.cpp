#include "texture.hpp"

#include "stb_image.h"

#include <string>
#include <glad/glad.h>
#include <iostream>
#include "framework/gl/program.hpp"
#include "config.hpp"

Texture::Texture() {
    glGenTextures(1, &textureID);
    for(unsigned int l = 0; l < Config::MAX_LAYERS; l++){
        pathID[l] = -1;
    }
}

Texture::Texture(GLenum textureUnit, int samplerID, std::string samplerName) {
    this->samplerID = samplerID;
    this->samplerName = samplerName;
    this->textureUnit = textureUnit;
    glGenTextures(1, &textureID);
    for(unsigned int l = 0; l < Config::MAX_LAYERS; l++){
        pathID[l] = -1;
    }
}

void Texture::load(unsigned int layerIndex) {
    glActiveTexture(textureUnit);
	glBindTexture(GL_TEXTURE_2D_ARRAY, textureID);

    int width, height, nrChannels;
    stbi_set_flip_vertically_on_load(true); 
    float *data = stbi_loadf(path[layerIndex].c_str(), &width, &height, &nrChannels, 0);
    if(data)
    {
        if(!loaded || (width != loadedWidth && height != loadedHeight)){
            glTexStorage3D(GL_TEXTURE_2D_ARRAY, 5, GL_RGB32F, width, height, Config::MAX_LAYERS);
            loaded = true;
            loadedHeight = height;
            loadedWidth = width;
            std::cout << "Initialized Texture: " << samplerName << " (" << width << "x" << height << ")" << std::endl;
        }
        glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, layerIndex, width, height, 1, GL_RGB, GL_FLOAT, data);
        stbi_image_free(data);

        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glGenerateMipmap(GL_TEXTURE_2D_ARRAY);

        std::cout << "Loaded Texture: " << samplerName << " -> " << path[layerIndex] << " (" << width << "x" << height << "x" << nrChannels << ")" << std::endl;
    }
    else
    {
        std::cout << "Texture failed to load at path: " << path[layerIndex] << std::endl;
        stbi_image_free(data);
    }
}
    
void Texture::bind(Program& program) {
    glActiveTexture(textureUnit);
	glBindTexture(GL_TEXTURE_2D_ARRAY, textureID);
    program.set(program.uniform(samplerName), samplerID);
}

void Texture::reloadAll() {
    for(unsigned int l = 0; l < Config::MAX_LAYERS; l++){
        if(!path[l].empty()) load(l);
    }
}