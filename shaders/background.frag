#version 330 core
out vec4 fragColor;

uniform vec2 uRes;
uniform float uT;

void main() {
    vec2 uv = gl_FragCoord.xy / uRes;
    fragColor = vec4(uv, 0.0, 1.0);
}