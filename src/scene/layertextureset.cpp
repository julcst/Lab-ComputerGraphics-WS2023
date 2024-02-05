#include "layertextureset.hpp"

#include <glad/glad.h>
#include "framework/gl/program.hpp"

LayerTextureSet::LayerTextureSet(){
    layerEtaTexture = Texture(GL_TEXTURE1, 1, "textureLayerEta");
    layerKappaTexture = Texture(GL_TEXTURE2, 2, "textureLayerKappa");
    layerAlphaTexture = Texture(GL_TEXTURE3, 3, "textureLayerAlpha");
}

void LayerTextureSet::bind(Program& program){
    layerEtaTexture.bind(program);
    layerKappaTexture.bind(program);
    layerAlphaTexture.bind(program);
}