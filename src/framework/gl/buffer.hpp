#pragma once

#include <glad/glad.h>

#include <vector>

/**
 * RAII wrapper for OpenGL vertex buffer
 */
class Buffer {
   public:
    enum class Type {
        ARRAY_BUFFER = GL_ARRAY_BUFFER,
        UNIFORM_BUFFER = GL_UNIFORM_BUFFER,
        INDEX_BUFFER = GL_ELEMENT_ARRAY_BUFFER,
    };
    enum class Usage {
        STATIC_DRAW = GL_STATIC_DRAW,
    };
    Buffer();
    // Disable copying
    Buffer(const Buffer&) = delete;
    Buffer& operator=(const Buffer&) = delete;
    // Implement moving
    Buffer(Buffer&& other);
    Buffer& operator=(Buffer&& other);
    ~Buffer();
    void bind(Type type);
    template <typename T>
    void load(Type type, const std::vector<T>& data, Usage usage = Usage::STATIC_DRAW);
    template <typename T>
    void load(Type type, const T& data, Usage usage = Usage::STATIC_DRAW);

   private:
    GLuint handle;
    void release();
    void load(Type type, GLsizeiptr size, const GLvoid* data, Usage usage);
};

template <typename T>
inline void Buffer::load(Type type, const std::vector<T>& data, Usage usage) {
    load(type, sizeof(T) * data.size(), data.data(), usage);
}

template <typename T>
inline void Buffer::load(Type type, const T& data, Usage usage) {
    load(type, sizeof(T), data, usage);
}