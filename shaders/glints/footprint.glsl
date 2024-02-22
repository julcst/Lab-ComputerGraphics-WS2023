#line 2 203
/**
 * Functions to estimate a pixel's footprint on the surface of the rendered object.
 */

/**
 * Three-dimensional parametrization of a pixel footprint ellipse.
 */
struct Footprint {
    float theta; // x-dimension: theta
    float aniso; // y-dimension: anisotropy
    float lod;   // z-dimension: lod or minorLength

    // Footprint ellipse can be reconstructed like this:
    // float majorLength = minorLength * aniso;
    // float minorLength = lod;
    // vec2 major = polarToCartesian(theta, majorLength)
    // float area = majorLength * minorLength
};

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
Footprint calcPixelFootprint(vec2 uv, float scale) {
    vec2 duvdx = scale * dFdx(uv);
    vec2 duvdy = scale * dFdy(uv);

    // Build the jacobian matrix J from the two partial derivatives
    // The constructor syntax is mat2(column1, column2)
    mat2 J = transpose(mat2(duvdx, duvdy)); // ? This may not be necessary

    mat2 Jinv = inverse(J); // ? This may not be necessary
    // Make J symmetric
    // M = (J^{-1})^T J^{-1}
    mat2 M = Jinv * transpose(Jinv);

    // Extract entries (GLSL is [column][row])
    float a = M[0][0];
	float b = M[1][0];
	float c = M[0][1];
	float d = M[1][1];

    // Find the eigenvalues and eigenvectors of M
    // (https://people.math.harvard.edu/~knill/teaching/math21b2004/exhibits/2dmatrices/index.html)
    float trace = a + d;
    float det = a * d - b * c;
    // Find roots with pq
    float mid = trace / 2.0;
    float dist = sqrt(trace * trace / 3.999999 - det);
    float L1 = mid - dist;
    float L2 = mid + dist;

    // Eigenvectors
    vec2 ev1 = normalize(vec2(L1 - d, c)); // major
    vec2 ev2 = normalize(vec2(L2 - d, c)); // minor

    // Eigenvalues
    float ew1 = 1.0 / sqrt(L1); // majorLength
	float ew2 = 1.0 / sqrt(L2); // minorLength

    Footprint footprint;

    // Footprint ellipse can be constructed like this:
    // footprint.area = ew1 * ew2;
    // footprint.major = ev1 * ew1;
    // footprint.minor = ev2 * ew2;
    // footprint.majorLength = ew1;
    // footprint.minorLength = ew2;

    // footprint.aniso = 1.0; // For debugging purposes
    // footprint.theta = DEG90; // For debugging purposes

    footprint.theta = atan(-ev1.x, ev1.y); // Matching reference implementation for comparability
    // footprint.theta = atan(ev1.y, ev1.x); // Alternative
    footprint.aniso = ew1 / ew2; // majorLength / minorLength
    footprint.lod = ew2; // minorLength
    return footprint;
}

/* Alternative implementations for the footprint calculation
Footprint calcNaivePixelFootprint(vec2 uv, float scale) {
    vec2 duvdx = scale * dFdx(uv);
    vec2 duvdy = scale * dFdy(uv);
    Footprint footprint;
    // Measured as the area of the parallelogram spanned by the two partial derivatives of the uv coordinates
    // footprint.area = length(cross(vec3(duvdx, 0.0), vec3(duvdy, 0.0)));
    return footprint;
}

Footprint calcWorldPixelFootprint(vec2 uv, vec3 worldPos, float scale) {
    vec2 duvdx = dFdx(uv);
    vec3 dpdx = scale * dFdx(worldPos);
    vec3 dpdy = scale * dFdy(worldPos);

    float Px = dot(dpdx, dpdx);
    float Py = dot(dpdy, dpdy);
    float Pmax = max(Px, Py);
    float Pmin = min(Px, Py);

    Footprint footprint;
    // footprint.area = length(cross(dpdx, dpdy));
    // footprint.theta = atan(duvdx.y, duvdx.x);
    // footprint.aniso = sqrt(Pmax / Pmin);
    return footprint;
}
*/