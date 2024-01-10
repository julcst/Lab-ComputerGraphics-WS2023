#version 330 core
#line 3 102

in VertexData {
    vec2 uv;
    vec3 worldPosition;
    vec3 worldNormal;
    vec3 worldTangent;
};
out vec3 fragColor;

float checkerboard(vec2 uv, float steps) {
    vec2 p = floor(uv * steps);
    return mod(p.x + p.y, 2.0);
}

vec3 normalToRGB(vec3 N) {
    return N * 0.5 + 0.5;
}

/**
 * Renders the normals and a uv checkerboard pattern onto the mesh
 */
void main() {
    vec3 N = normalize(worldNormal);
    fragColor = normalToRGB(N) * (checkerboard(uv, 100.0) * 0.5 + 0.5);
}