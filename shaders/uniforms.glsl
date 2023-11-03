/**
 * UB0 binds at index 0 and stores information about the scene that is only uploaded once per frame
 */
layout(std140) uniform UB0 {
    vec3 uLightDir;
    float uAspectRatio;
    vec3 uSkyColor;
    float uFocalLength;
    mat3 uCameraRotation;
};

/**
 * UB1 binds at index 1 and stores information about the current object being rendered
 * and is uploaded once per object
 */
layout(std140) uniform UB1 {
    vec3 uAlbedo;
    mat4 uMVP;
    mat3 uModel;
};