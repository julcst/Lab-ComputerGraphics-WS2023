/**
 * UB0 binds at index 0 and stores information about the scene that is only uploaded once per frame
 */
layout(std140) uniform UB0 {
    vec3 uLightDir;
    float uAspectRatio;
    vec3 uSkyColor;
    float uFocalLength;
    vec3 uLightColor;
    float uAmbientStrength;
    vec3 uCameraPosition;
    mat3 uCameraRotation;
};

/**
 * UB1 binds at index 1 and stores information about the current object being rendered
 * and is uploaded once per object
 */
layout(std140) uniform UB1 {

//////////// GGX parameters ///////////
    vec3 uAlbedo;
    float uRoughness;
    float uMetallic;

////////// Glints parameters //////////
    float uScreenSpaceScale;
    float uLogMicrofacetDensity;
    /** 
     * From the paper:
     *    "R defines another probability of microfacets being reflecting or
     * non-reflecting for any half-vector. This parameter is ad-hoc and we
     * cannot completely link it to a physical quantity. However, in prac-
     * tice, it behaves close to a microfacet roughness parameter: low R
     * will reduce the amount of glints and increase their intensity"
     */
    float uMicrofacetRoughness;
    float uDensityRandomization;

/////// Transformation matrices ///////
    mat4 uMVP;
    mat3 uModel;
};