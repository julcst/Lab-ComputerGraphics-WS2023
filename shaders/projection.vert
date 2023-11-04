#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texCoord;
layout (location = 2) in vec3 normal;
out vec3 pos;
out vec2 uv;
out vec3 n;
out vec3 worldPos;

#include "uniforms.glsl"

/**
 * Applies the model, view, and projection matrices to a mesh
 */
void main() {
    gl_Position = uMVP * vec4(position, 1.0);
    pos = position;
    uv = texCoord;
    n = uModel * normal;
    worldPos = position;
}