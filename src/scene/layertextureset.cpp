#include "layertextureset.hpp"

#include <glad/glad.h>
#include "framework/gl/program.hpp"

LayerTextureSet::LayerTextureSet(){
    layerEtaTexture = Texture(GL_TEXTURE0, 0, "textureLayerEta", GL_RGB);
    layerKappaTexture = Texture(GL_TEXTURE1, 1, "textureLayerKappa", GL_RGB);
    layerAlphaTexture = Texture(GL_TEXTURE2, 2, "textureLayerAlpha", GL_RED);
}

void LayerTextureSet::bind(Program& program){
    layerEtaTexture.bind(program);
    layerKappaTexture.bind(program);
    layerAlphaTexture.bind(program);
}