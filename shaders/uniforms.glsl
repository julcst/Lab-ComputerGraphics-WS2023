layout(std140) uniform Uniforms {
    vec3 uLightDir;
    float uAspectRatio;
    vec3 uSkyColor;
    float uFocalLength;
    mat3 uCameraRotation;
};