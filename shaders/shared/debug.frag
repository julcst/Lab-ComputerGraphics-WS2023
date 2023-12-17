#version 330 core
#line 3 102

in vec3 pos;
in vec2 uv;
in vec3 n;
out vec3 fragColor;

float checkerboard(vec2 uv, float steps) {
    vec2 p = floor(uv * steps);
    return mod(p.x + p.y, 2.0);
}

vec3 normalToRGB(vec3 N) {
    return N * 0.5 + 0.5;
}

/**
 * Renders the normals and a checkerboard pattern onto the mesh
 */
void main() {
    vec3 N = normalize(n);
    fragColor = normalToRGB(N) * (checkerboard(uv, 100.0) * 0.5 + 0.5);
}