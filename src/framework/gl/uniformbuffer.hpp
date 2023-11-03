#pragma once

#include "buffer.hpp"

template <typename T>
class UniformBuffer {
   public:
    T uniforms;
    UniformBuffer(unsigned int index, const T& uniforms = T{});
    void upload();
    void bind(unsigned int index);

   private:
    Buffer buffer;
};

template <typename T>
UniformBuffer<T>::UniformBuffer(unsigned int index, const T& uniforms) : buffer(), uniforms(uniforms) {
    buffer.bindUBO(index);
    buffer.load(Buffer::Type::UNIFORM_BUFFER, uniforms);
}

template <typename T>
void UniformBuffer<T>::upload() {
    buffer.set(Buffer::Type::UNIFORM_BUFFER, uniforms);
}

template <typename T>
void UniformBuffer<T>::bind(unsigned int index) {
    buffer.bindUBO(index);
}