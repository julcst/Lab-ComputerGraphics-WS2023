/**
 * Functions to estimate a pixel's footprint on the surface of the rendered object.
 */

struct Footprint {
    /** The area of the pixel footprint. */
    float area;
};

/**
 * Calculates the footprint of a pixel by measuring the area of the parallelogram spanned by the two
 * partial derivatives of the uv coordinates.
 */
Footprint calcNaivePixelFootprint(vec2 uv, float scale) {
    vec2 duvdx = scale * dFdx(uv);
    vec2 duvdy = scale * dFdy(uv);
    Footprint footprint;
    // Measured as the area of the parallelogram spanned by the two partial derivatives of the uv coordinates
    footprint.area = 0.5 * length(cross(vec3(duvdx, 0.0), vec3(duvdy, 0.0)));
    return footprint;
}

// TODO implement footprint ellipse calculation
/**
 * Calculates the footprint of a pixel by constructing a footprint ellipse, which major and minor axis
 * are calculated as the Eigenvectors of the matrix J that deforms the unit circle into the footprint.
 *
 * The partial derivatives of the uv coordinates (duvdx, duvdy) are the derivatives of a 2D transformation.
 * Therefore the matrix J is a Jacobian matrix formed by these partial derivatives that locally approximates the
 * projective deformation of the uv mapping as a linear transformation.
 * Then the Eigenvectors of J are the major and minor axis of the ellipse that best represents
 * the local behavior of the transformation and therefore the footprint of the pixel.
 */