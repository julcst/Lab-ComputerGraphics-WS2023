#include "mesh.hpp"

#include <glad/glad.h>

#include <vector>

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

void Mesh::draw() {
    vao.bind();
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0);
    vao.unbind();
}