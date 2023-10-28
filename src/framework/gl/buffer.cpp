#include "buffer.hpp"

#include <glad/glad.h>

#include <cassert>
#include <vector>

/////////////////////// RAII behavior ///////////////////////
Buffer::Buffer() {
    glGenBuffers(1, &handle);
    assert(handle);
}

Buffer::Buffer(Buffer&& other) : handle(other.handle) {
    other.handle = 0;
}

Buffer& Buffer::operator=(Buffer&& other) {
    if (this != &other) {
        release();
        handle = other.handle;
        other.handle = 0;
    }
    return *this;
}

Buffer::~Buffer() {
    release();
}

void Buffer::release() {
    if (handle) glDeleteBuffers(1, &handle);
}
/////////////////////////////////////////////////////////////

void Buffer::bind(Type type) {
    glBindBuffer(static_cast<GLenum>(type), handle);
}

void Buffer::load(Type type, GLsizeiptr size, const GLvoid* data, Usage usage) {
    bind(type);
    glBufferData(static_cast<GLenum>(type), size, data, static_cast<GLenum>(usage));
}