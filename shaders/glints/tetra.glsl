#include "glints/barycentric.glsl"
#line 2 210

/**
 * Conatins the four vertices of a tetrahedron in the (area, ratio, orientation) space
 * and the barycentric weights of the current pixel footprint inside the tetrahedron
 */
struct Tetrahedron {
    vec3 p0, p1, p2, p3;
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
Tetrahedron getTetrahedron(Heptahedron hepta, bool centerCase) {
    Tetrahedron tetra;

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

        // Upper pyramid acdef
        if (hepta.lodWeight > 1.0 - hepta.anisoWeight) {
            // Left-up tetrahedron aedf
			if (map01(hepta.lodWeight, 1.0 - hepta.anisoWeight, 1.0) > hepta.thetaWeight) {
				tetra.p0 = a; tetra.p1 = e; tetra.p2 = d; tetra.p3 = f;
            // Right-down tetrahedron feca
            } else {
				tetra.p0 = f; tetra.p1 = e; tetra.p2 = c; tetra.p3 = a;
			}
        // Lower tetrahedron bace
		} else {
			tetra.p0 = b; tetra.p1 = a; tetra.p2 = c; tetra.p3 = e;
		}
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

        // Firstly cut the heptahedron up into three prisms: abcfgh, bcdghi, cdehij
        // Then cut these prisms into three tetrahedrons each
        // Prism abcfgh
        if (hepta.thetaWeight < 0.5 && hepta.thetaWeight * 2.0 < hepta.anisoWeight) {
            // Upper pyramid acfgh
            if (hepta.lodWeight > 1.0 - hepta.anisoWeight) {
                // Tetrahedron afhg
                if (map01(hepta.lodWeight, 1.0 - hepta.anisoWeight, 1.0) > map01(hepta.thetaWeight * 2.0, 0.0, hepta.anisoWeight)) {
                    tetra.p0 = a; tetra.p1 = f; tetra.p2 = h; tetra.p3 = g;
                // Tetrahedron cahg
                } else {
                    tetra.p0 = c; tetra.p1 = a; tetra.p2 = h; tetra.p3 = g;
                }
            // Tetrahedron bacg
            } else {
                tetra.p0 = b; tetra.p1 = a; tetra.p2 = c; tetra.p3 = g;
            }
        // Prism bcdghi
        } else if (1.0 - ((hepta.thetaWeight - 0.5) * 2.0) > hepta.anisoWeight) {
            // Lower pyramid bcdgi
            if (hepta.lodWeight < 1.0 - hepta.anisoWeight) {
                // Tetrahedron bgic
                if (map01(hepta.lodWeight, 0.0, 1.0 - hepta.anisoWeight) > map01(hepta.thetaWeight, 0.5 - (1.0 - hepta.anisoWeight) * 0.5, 0.5 + (1.0 - hepta.anisoWeight) * 0.5)) {
                    tetra.p0 = b; tetra.p1 = g; tetra.p2 = i; tetra.p3 = c;
                // Tetrahedron dbci
                } else {
                    tetra.p0 = d; tetra.p1 = b; tetra.p2 = c; tetra.p3 = i;
                }
            // Tetrahedron cghi
            } else {
                tetra.p0 = c; tetra.p1 = g; tetra.p2 = h; tetra.p3 = i;
            }
        // Prism cdehij
        } else {
            // Upper pyramid cehij
            if (hepta.lodWeight > 1.0 - hepta.anisoWeight) {
                // Tetrahedron cjhi
                if (map01(hepta.lodWeight, 1.0 - hepta.anisoWeight, 1.0) > map01(hepta.thetaWeight * 2.0, 1.0 - hepta.anisoWeight, 1.0)) {
                    tetra.p0 = c; tetra.p1 = j; tetra.p2 = h; tetra.p3 = i;
                // Tetrahedron eicj
                } else {
                    tetra.p0 = e; tetra.p1 = i; tetra.p2 = c; tetra.p3 = j;
                }
            // Tetrahedron deci
            } else {
                tetra.p0 = d; tetra.p1 = e; tetra.p2 = c; tetra.p3 = i;
            }
        }
    }
    return tetra;
}

Tetrahedron tetrifyFootprint(Heptahedron hepta, Footprint foot, bool centerCase) {
    Tetrahedron tetra = getTetrahedron(hepta, centerCase);
    vec3 p = vec3(fmod(foot.angle, DEG180), foot.ratio, foot.minorLength);
    tetra.weights = calcBarycentric(p, tetra.p0, tetra.p1, tetra.p2, tetra.p3);
    return tetra;
}