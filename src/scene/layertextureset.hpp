#pragma once

#include "scene/texture.hpp"
#include "framework/gl/program.hpp"

class LayerTextureSet {
   public:
    LayerTextureSet();
    void bind(Program& program);
    Texture layerEtaTexture;
    Texture layerKappaTexture;
    Texture layerAlphaTexture;
};