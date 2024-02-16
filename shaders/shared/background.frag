#version 330 core

in vec3 viewDir;
out vec3 fragColor;

#include "shared/uniforms.glsl"
#line 8 101

/**
 * Renders a simple procedural sky and sun
 */
void main() {
    vec3 rayDir = normalize(viewDir);
    if (uUseCubemap) {
        fragColor = texture(cubemap,rayDir).rgb;
    } else{
        vec3 sky = exp(-abs(rayDir.y) / uSkyColor);
        float sun = pow(max(0.0, dot(rayDir, uLightDir)), 1000);
        fragColor = sky + sun * vec3(1.0);
    }
}