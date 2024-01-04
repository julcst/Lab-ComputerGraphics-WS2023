#include "glints/math.glsl"
#line 2 210

// TODO: Use this for cutting the heptahedron
/**
 * Given a plane defined by three points a, b, c and a point p, this function returns true
 * if p is on the same side of the plane as the normal vector of the plane.
 */
bool calcPlaneSide(vec3 p, vec3 a, vec3 b, vec3 c) {
    vec3 ab = b - a;
    vec3 ac = c - a;
    vec3 ap = p - a;
    vec3 n = cross(ab, ac);
    return dot(n, ap) >= 0.0;
}

/**
 * Conatins the four vertices of a tetrahedron in the (area, ratio, orientation) space
 * and the barycentric weights of the current pixel footprint inside the tetrahedron
 */
struct Tetrahedron {
    vec3 p0, p1, p2, p3;
    vec3 P0, P1, P2, P3;
    vec4 weights;
};

/**
 * Splits the heptahedron into six tetrahedra by first splitting it into three prisms along the ground pentagon shape
 * and then splitting each prism into two tetrahedra along the diagonal
 *
 * NOTE:  In difference to the reference implementation I do not return the points of the tetrahedron relative to the heptahedron but in absolute coordinates.
 *        This avoids the dynamic indexing process used in the reference implementation and may benefit performance.
 *        Dynamic indexing can be costly because it may require the use of pointers instead of registers.
 */
Tetrahedron getTetrahedron(Heptahedron hepta, bool centerCase, vec3 p) {
    Tetrahedron tetra;

    float thetaLerp = hepta.thetaWeight;
    float anisoLerp = hepta.anisoWeight;
    // ! Why is this in log space in the reference implementation
    // NOTE: May not matter much
    float lodLerp = hepta.lodWeight;

    // TODO: Thoroughly understand cutting
    //////////////////// Center Case ////////////////////
    if (centerCase) {
        // The points of the hexahedron in the form vec3(theta, aniso, area)
        // Ground triangle (lod0)
        vec3 a = vec3(hepta.theta0, hepta.aniso1, hepta.lod0);
        vec3 b = vec3(hepta.theta0, hepta.aniso0, hepta.lod0);
        vec3 c = vec3(hepta.theta1, hepta.aniso1, hepta.lod0); // e in heptahedron
        // Top triangle (lod1)
        vec3 d = vec3(hepta.theta0, hepta.aniso1, hepta.lod1); // f in heptahedron
        vec3 e = vec3(hepta.theta0, hepta.aniso0, hepta.lod1); // g in heptahedron
        vec3 f = vec3(hepta.theta1, hepta.aniso1, hepta.lod1); // j in heptahedron

        // Ground triangle (lod0)
        vec3 A = vec3(0.0, 1.0, 0.0);
        vec3 B = vec3(0.0, 0.0, 0.0);
        vec3 C = vec3(1.0, 1.0, 0.0); // e in heptahedron
        // Top triangle (lod1)
        vec3 D = vec3(0.0, 1.0, 1.0); // f in heptahedron
        vec3 E = vec3(0.0, 0.0, 1.0); // g in heptahedron
        vec3 F = vec3(1.0, 1.0, 1.0); // j in heptahedron

        // Upper pyramid acdef
        if (lodLerp > 1.0 - anisoLerp) {
            // Left-up tetrahedron aedf
			if (map01(lodLerp, 1.0 - anisoLerp, 1.0) > thetaLerp) {
				tetra.p0 = a; tetra.p1 = e; tetra.p2 = d; tetra.p3 = f;
                tetra.P0 = A; tetra.P1 = E; tetra.P2 = D; tetra.P3 = F;
            // Right-down tetrahedron feca
            } else {
				tetra.p0 = f; tetra.p1 = e; tetra.p2 = c; tetra.p3 = a;
                tetra.P0 = F; tetra.P1 = E; tetra.P2 = C; tetra.P3 = A;
			}
        // Lower tetrahedron bace
		} else {
			tetra.p0 = b; tetra.p1 = a; tetra.p2 = c; tetra.p3 = e;
            tetra.P0 = B; tetra.P1 = A; tetra.P2 = C; tetra.P3 = E;
		}
        /*// Upper pyramid acdef -> cut along plane ace
        if (!calcPlaneSide(p, a, c, e)) {
            // Left-up tetrahedron aedf -> cut along plane aef
			if (calcPlaneSide(p, a, e, f)) {
				tetra.p0 = a; tetra.p1 = e; tetra.p2 = d; tetra.p3 = f;
                tetra.P0 = A; tetra.P1 = E; tetra.P2 = D; tetra.P3 = F;
            // Right-down tetrahedron feca
            } else {
				tetra.p0 = f; tetra.p1 = e; tetra.p2 = c; tetra.p3 = a;
                tetra.P0 = F; tetra.P1 = E; tetra.P2 = C; tetra.P3 = A;
			}
        // Lower tetrahedron bace
		} else {
			tetra.p0 = b; tetra.p1 = a; tetra.p2 = c; tetra.p3 = e;
            tetra.P0 = B; tetra.P1 = A; tetra.P2 = C; tetra.P3 = E;
		}*/
    //////////////////// Normal Case ////////////////////
    } else { 

        // The points of the hepathedron in the form vec3(theta, aniso, area)
        // Ground pentagon (lod0), triangularization: abc, bcd, cde
        vec3 a = vec3(hepta.theta0, hepta.aniso1, hepta.lod0);
        vec3 b = vec3(hepta.theta0, hepta.aniso0, hepta.lod0);
        vec3 c = vec3(hepta.thetaH, hepta.aniso1, hepta.lod0);
        vec3 d = vec3(hepta.theta1, hepta.aniso0, hepta.lod0);
        vec3 e = vec3(hepta.theta1, hepta.aniso1, hepta.lod0);
        // Top pentagon (lod1), triangularization: fgh, ghi, hij
        vec3 f = vec3(hepta.theta0, hepta.aniso1, hepta.lod1);
        vec3 g = vec3(hepta.theta0, hepta.aniso0, hepta.lod1);
        vec3 h = vec3(hepta.thetaH, hepta.aniso1, hepta.lod1);
        vec3 i = vec3(hepta.theta1, hepta.aniso0, hepta.lod1);
        vec3 j = vec3(hepta.theta1, hepta.aniso1, hepta.lod1);

        // Ground pentagon (lod0), triangularization: abc, bcd, cde
        vec3 A = vec3(0.0, 1.0, 0.0);
        vec3 B = vec3(0.0, 0.0, 0.0);
        vec3 C = vec3(0.5, 1.0, 0.0);
        vec3 D = vec3(1.0, 0.0, 0.0);
        vec3 E = vec3(1.0, 1.0, 0.0);
        // Top pentagon (lod1), triangularization: fgh, ghi, hij
        vec3 F = vec3(0.0, 1.0, 1.0);
        vec3 G = vec3(0.0, 0.0, 1.0);
        vec3 H = vec3(0.5, 1.0, 1.0);
        vec3 I = vec3(1.0, 0.0, 1.0);
        vec3 J = vec3(1.0, 1.0, 1.0);

        // Firstly cut the heptahedron up into three prisms: abcfgh, bcdghi, cdehij
        // Then cut these prisms into three tetrahedrons each
        // Prism abcfgh
        if (thetaLerp < 0.5 && thetaLerp * 2.0 < anisoLerp) {
            // Upper pyramid acfgh
            if (lodLerp > 1.0 - anisoLerp) {
                // Tetrahedron afhg
                if (map01(lodLerp, 1.0 - anisoLerp, 1.0) > map01(thetaLerp * 2.0, 0.0, anisoLerp)) {
                    tetra.p0 = a; tetra.p1 = f; tetra.p2 = h; tetra.p3 = g;
                    tetra.P0 = A; tetra.P1 = F; tetra.P2 = H; tetra.P3 = G;
                // Tetrahedron cahg
                } else {
                    tetra.p0 = c; tetra.p1 = a; tetra.p2 = h; tetra.p3 = g;
                    tetra.P0 = C; tetra.P1 = A; tetra.P2 = H; tetra.P3 = G;
                }
            // Tetrahedron bacg
            } else {
                tetra.p0 = b; tetra.p1 = a; tetra.p2 = c; tetra.p3 = g;
                tetra.P0 = B; tetra.P1 = A; tetra.P2 = C; tetra.P3 = G;
            }
        // Prism bcdghi
        } else if (1.0 - ((thetaLerp - 0.5) * 2.0) > anisoLerp) {
            // Lower pyramid bcdgi
            if (lodLerp < 1.0 - anisoLerp) {
                // Tetrahedron bgic
                if (map01(lodLerp, 0.0, 1.0 - anisoLerp) > map01(thetaLerp, 0.5 - (1.0 - anisoLerp) * 0.5, 0.5 + (1.0 - anisoLerp) * 0.5)) {
                    tetra.p0 = b; tetra.p1 = g; tetra.p2 = i; tetra.p3 = c;
                    tetra.P0 = B; tetra.P1 = G; tetra.P2 = I; tetra.P3 = C;
                // Tetrahedron dbci
                } else {
                    tetra.p0 = d; tetra.p1 = b; tetra.p2 = c; tetra.p3 = i;
                    tetra.P0 = D; tetra.P1 = B; tetra.P2 = C; tetra.P3 = I;
                }
            // Tetrahedron cghi
            } else {
                tetra.p0 = c; tetra.p1 = g; tetra.p2 = h; tetra.p3 = i;
                tetra.P0 = C; tetra.P1 = G; tetra.P2 = H; tetra.P3 = I;
            }
        // Prism cdehij
        } else {
            // Upper pyramid cehij
            if (lodLerp > 1.0 - anisoLerp) {
                // Tetrahedron cjhi
                if (map01(lodLerp, 1.0 - anisoLerp, 1.0) > map01(thetaLerp * 2.0, 1.0 - anisoLerp, 1.0)) {
                    tetra.p0 = c; tetra.p1 = j; tetra.p2 = h; tetra.p3 = i;
                    tetra.P0 = C; tetra.P1 = J; tetra.P2 = H; tetra.P3 = I;
                // Tetrahedron eicj
                } else {
                    tetra.p0 = e; tetra.p1 = i; tetra.p2 = c; tetra.p3 = j;
                    tetra.P0 = E; tetra.P1 = I; tetra.P2 = C; tetra.P3 = J;
                }
            // Tetrahedron deci
            } else {
                tetra.p0 = d; tetra.p1 = e; tetra.p2 = c; tetra.p3 = i;
                tetra.P0 = D; tetra.P1 = E; tetra.P2 = C; tetra.P3 = I;
            }
        }
    }
    return tetra;
}

Tetrahedron tetrifyFootprint(Heptahedron hepta, Footprint foot, bool centerCase) {
    vec3 p = vec3(foot.angle, foot.ratio, foot.minorLength);
    vec3 P = vec3(hepta.thetaWeight, hepta.anisoWeight, hepta.lodWeight);
    Tetrahedron tetra = getTetrahedron(hepta, centerCase, p);
    tetra.weights = calcBarycentrics(P, tetra.P0, tetra.P1, tetra.P2, tetra.P3);
    return tetra;
}