#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texCoord;
layout (location = 2) in vec3 normal;
layout (location = 3) in vec3 tangent;
layout (location = 4) in vec3 bitangent;
out vec2 uv;
out vec3 n;
out vec3 t;
out vec3 b;
out vec3 worldPos;

#include "shared/uniforms.glsl"
#line 12 107

/**
 * Applies the model, view, and projection matrices to a mesh
 */
void main() {
    gl_Position = uMVP * vec4(position, 1.0);
    uv = texCoord;
    n = (uModel * vec4(normal, 0.0)).xyz;
    t = (uModel * vec4(tangent, 0.0)).xyz;
    b = (uModel * vec4(bitangent, 0.0)).xyz;
    worldPos = (uModel * vec4(position, 1.0)).xyz;
}