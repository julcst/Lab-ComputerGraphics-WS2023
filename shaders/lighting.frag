#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
out vec3 fragColor;

void main() {
    fragColor = vec3(n);
}