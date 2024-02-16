#pragma once

#include <nlohmann/json.hpp>

#include "scene/texture.hpp"
#include "framework/gl/program.hpp"

class LayerTextureSet {
   public:
    LayerTextureSet();
    void bind(Program& program);
    void reloadAll();
    Texture layerEtaTexture;
    Texture layerKappaTexture;
    Texture layerAlphaTexture;

    NLOHMANN_DEFINE_TYPE_INTRUSIVE(LayerTextureSet, layerEtaTexture, layerKappaTexture, layerAlphaTexture);
};