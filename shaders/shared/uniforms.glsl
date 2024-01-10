#line 2 111
#define MAX_LAYERS 4

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
    /**
     * From the paper: "the minimal allowed size of a glint in pixels. Due to
     * Shannon's sampling theorem, using 1 here results in aliasing.
     * We recommend using 1.5"
     */
    float uScreenSpaceScale;
    /**
     * From the paper: "the (log) amount of microfacets per unit surface
     * texture space area"
     */
    float uLogMicrofacetDensity;
    /** 
     * From the paper:
     *   "R defines another probability of microfacets being reflecting or
     * non-reflecting for any half-vector. This parameter is ad-hoc and we
     * cannot completely link it to a physical quantity. However, in prac-
     * tice, it behaves close to a microfacet roughness parameter: low R
     * will reduce the amount of glints and increase their intensity"
     */
    float uMicrofacetRoughness;
    /**
     * From the paper: the amount of randomization of glint densities
     * across the surface
     */
    float uDensityRandomization;
    uint uDebug;

/////// GGX Anisotropic ///////    
    float uAlphaX;
    float uAlphaY;

/////// Transformation matrices ///////
    mat4 uLocalToClip;
    mat4 uLocalToWorld;

////////// Layered parameters //////////
    uint uLayerCount;
    vec4 uLayerEta[MAX_LAYERS];
    vec4 uLayerKappa[MAX_LAYERS];
    vec4 uLayerAlpha[MAX_LAYERS/4];
    vec4 uLayerDepth[MAX_LAYERS/4];
    vec4 uLayerSigmaA[MAX_LAYERS];
    vec4 uLayerSigmaS[MAX_LAYERS];
    vec4 uLayerG[MAX_LAYERS/4];
};