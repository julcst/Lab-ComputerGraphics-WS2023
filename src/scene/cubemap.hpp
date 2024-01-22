#pragma once

#include <string>
#include <vector>

class Cubemap {
   public:
    Cubemap();
    void load(std::string cubemapName);
    void bind();
    int id = -1;

   private:
    unsigned int textureID;
    const std::vector<std::string> faces {"_px.hdr", "_nx.hdr", "_py.hdr", "_ny.hdr", "_pz.hdr", "_nz.hdr" };
};