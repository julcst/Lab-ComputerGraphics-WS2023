#version 330 core

in vec3 viewDir;
out vec3 fragColor;

#include "uniforms.glsl"

/**
 * Renders a simple procedural sky and sun
 */
void main() {
    vec3 rayDir = normalize(viewDir);
    vec3 sky = exp(-abs(rayDir.y) / uSkyColor);
    float sun = pow(max(0.0, dot(rayDir, uLightDir)), 1000);
    fragColor = sky + sun * vec3(1.0);
}