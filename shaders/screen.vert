#version 330 core

layout (location = 0) in vec3 position;
out vec3 viewDir;

#include "uniforms.glsl"

void main() {
    gl_Position = vec4(position, 1.0);
    viewDir = mat3(uCameraRotation) * vec3(position.x * uAspectRatio, position.y, uFocalLength);
}