#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
out vec3 fragColor;

#include "uniforms.glsl"

void main() {
    fragColor = uAlbedo * max(dot(uLightDir, n), 0.0) / 3.1415926 + uSkyColor * 0.1;
}