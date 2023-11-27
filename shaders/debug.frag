#version 330 core

in vec3 pos;
in vec2 uv;
in vec3 n;
out vec3 fragColor;

float checkerboard(vec2 uv, float steps) {
    vec2 p = floor(uv * steps);
    return mod(p.x + p.y, 2.0);
}

/**
 * Renders the normals and a checkerboard pattern onto the mesh
 */
void main() {
    vec3 N = normalize(n);
    fragColor = abs(N) * (checkerboard(uv, 100.0) * 0.5 + 0.5);
}