#include "mesh.hpp"

#include <glad/glad.h>
#include <objgl.h>

#include <fstream>
#include <string>
#include <vector>

#include "common.hpp"
#include "config.hpp"

void Mesh::load(const std::vector<float>& vertices, const std::vector<unsigned int>& indices) {
    // Load data into buffers
    numVertices = vertices.size();
    numIndices = indices.size();
    vbo.load(Buffer::Type::ARRAY_BUFFER, vertices);
    ebo.load(Buffer::Type::INDEX_BUFFER, indices);

    // Bind buffers to VAO
    // TODO: Use DSA instead (but only OpenGL 4.5+, so not on macOS)
    vao.bind();
    vbo.bind(Buffer::Type::ARRAY_BUFFER);
    ebo.bind(Buffer::Type::INDEX_BUFFER);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    vao.unbind();
}

void Mesh::load(const std::string& filepath) {
    // read file
    std::string rawobj = Common::readFile(filepath);

    // parse
    ObjGLData model = objgl_loadObj(rawobj.c_str());

    numVertices = model.numVertices;
    numIndices = model.numIndices;

    // load buffers
    vbo._load(Buffer::Type::ARRAY_BUFFER, numVertices * model.vertSize, model.data);
    ebo._load(Buffer::Type::INDEX_BUFFER, numIndices * sizeof(uint_least32_t), model.indices);

    vao.bind();
    vbo.bind(Buffer::Type::ARRAY_BUFFER);
    ebo.bind(Buffer::Type::INDEX_BUFFER);

    // vertex atributes
    // location 0 position
    // location 1 texture coordinates
    // location 2 normals
    if (model.hasNormals && !model.hasTexCoords) {
        // positions and normals
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(2);
    } else if (!model.hasNormals && model.hasTexCoords) {
        // positions and texture coordinates
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
    } else if (model.hasNormals && model.hasTexCoords) {
        // positons, normals and texture coordinates
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
        glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(5 * sizeof(float)));
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glEnableVertexAttribArray(2);
    } else {
        // only positions
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(0);
    }

    vao.unbind();

    // cleanup
    objgl_delete(&model);
}

void Mesh::draw() {
    vao.bind();
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0);
    vao.unbind();
}