#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texCoord;
layout (location = 2) in vec3 normal;
out vec3 pos;
out vec2 uv;
out vec3 n;

uniform mat4 uMVP;

void main() {
    gl_Position = uMVP * vec4(position, 1.0);
    pos = position;
    uv = texCoord;
    n = normal;
}