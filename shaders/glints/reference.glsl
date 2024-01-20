/**
 * This is exactly the reference implementation that was published by the authors along their paper
 * Deliot, T., and L. Belcour. "Real-Time Rendering of Glinty Appearances using Distributed Binomial Laws on Anisotropic Grids." (2023)
 * which is available under (https://ggx-research.github.io/publication/2023/06/09/publication-glints.html)
 * I just converted it to GLSL
 * This is only used to test my implementation against their reference implementation
 */

#include "shared/debug.glsl"
#include "shared/uniforms.glsl"
#line 12 209

#define mupi 3.141592
#define muiupi 0.318309
#define muiusqrtu2 0.707106
const float DEG2RAD = 0.01745329251;
const float RAD2DEG = 57.2957795131;

/*
Texture2D<vec4> uGlint2023NoiseMap;
int uGlint2023NoiseMapSize;
float uScreenSpaceScale;
float uLogMicrofacetDensity;
float uMicrofacetRoughness;
float uDensityRandomization;
*/

// HLSL to GLSL
#define saturate(x) clamp(x, 0.0, 1.0)
#define mul(a, b) a * b
#define asuint(x) floatBitsToUint(x)
#define lerp(a, b, t) mix(a, b, t)
#define atan2(y, x) atan(y, x)
#define frac(x) fract(x)
#define float2 vec2
#define float3 vec3
#define float4 vec4
#define int2 ivec2
#define int3 ivec3
#define int4 ivec4
#define uint2 uvec2
#define uint3 uvec3
#define uint4 uvec4
#define float2x2 mat2
#define float3x3 mat3
#define float4x4 mat4

//=======================================================================================
// TOOLS
//=======================================================================================

/**
 * Inverse Error function used to sample normal distribution
 */
float erfinv(float x)
{
	float w, p;
	w = -log((1.0 - x) * (1.0 + x));
	if (w < 5.000000)
	{
		w = w - 2.500000;
		p = 2.81022636e-08;
		p = 3.43273939e-07 + p * w;
		p = -3.5233877e-06 + p * w;
		p = -4.39150654e-06 + p * w;
		p = 0.00021858087 + p * w;
		p = -0.00125372503 + p * w;
		p = -0.00417768164 + p * w;
		p = 0.246640727 + p * w;
		p = 1.50140941 + p * w;
	}
	else
	{
		w = sqrt(w) - 3.000000;
		p = -0.000200214257;
		p = 0.000100950558 + p * w;
		p = 0.00134934322 + p * w;
		p = -0.00367342844 + p * w;
		p = 0.00573950773 + p * w;
		p = -0.0076224613 + p * w;
		p = 0.00943887047 + p * w;
		p = 1.00167406 + p * w;
		p = 2.83297682 + p * w;
	}
	return p * x;
}

vec3 sampleNormalDistribution(vec3 u, float mu, float sigma)
{
	//return mu + sigma * (sqrt(-2.0 * log(u.x))* cos(2.0 * pi * u.y));
	float x0 = sigma * 1.414213f * erfinv(2.0 * u.x - 1.0) + mu;
	float x1 = sigma * 1.414213f * erfinv(2.0 * u.y - 1.0) + mu;
	float x2 = sigma * 1.414213f * erfinv(2.0 * u.z - 1.0) + mu;
	return vec3(x0, x1, x2);
}

vec4 sampleNormalDistribution(vec4 u, float mu, float sigma)
{
	//return mu + sigma * (sqrt(-2.0 * log(u.x))* cos(2.0 * pi * u.y));
	float x0 = sigma * 1.414213f * erfinv(2.0 * u.x - 1.0) + mu;
	float x1 = sigma * 1.414213f * erfinv(2.0 * u.y - 1.0) + mu;
	float x2 = sigma * 1.414213f * erfinv(2.0 * u.z - 1.0) + mu;
	float x3 = sigma * 1.414213f * erfinv(2.0 * u.w - 1.0) + mu;
	return vec4(x0, x1, x2, x3);
}

vec3 pcg3dFloat(uvec3 v)
{
	v = v * 1664525u + 1013904223u;

	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;

	v ^= v >> 16u;

	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;

	return v * (1.0 / 4294967296.0);
}

vec4 pcg4dFloat(uvec4 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
    v ^= v >> 16u;
    v.x += v.y * v.w; v.y += v.z * v.x; v.z += v.x * v.y; v.w += v.y * v.z;
    return v * (1.0 / 4294967296.0);
}

vec4 pcg4dFloat(vec4 v) {
    return pcg4dFloat(floatBitsToUint(v));
}

float HashWithoutSine13(vec3 p3)
{
	p3 = fract(p3 * .1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

/* NOTE: Not translated
mat2 Inverse(mat2 A)
{
	return mat2(A[1][1], -A[0][1], -A[1][0], A[0][0]) / determinant(A);
}
*/

void GetGradientEllipse(vec2 duvdx, vec2 duvdy, out vec2 ellipseMajor, out vec2 ellipseMinor)
{
	// Transposed because HLSL->GLSL
	mat2 J = transpose(mat2(duvdx, duvdy));
	J = inverse(J); // inverse is a GLSL function
	J = mul(J, transpose(J));

	// Indices swapped because HLSL->GLSL
	float a = J[0][0];
	float b = J[1][0];
	float c = J[0][1];
	float d = J[1][1];

	float T = a + d;
	float D = a * d - b * c;
	float L1 = T / 2.0 - pow(T * T / 3.99999 - D, 0.5);
	float L2 = T / 2.0 + pow(T * T / 3.99999 - D, 0.5);

	vec2 A0 = vec2(L1 - d, c);
	vec2 A1 = vec2(L2 - d, c);
	float r0 = 1.0 / sqrt(L1);
	float r1 = 1.0 / sqrt(L2);
	ellipseMajor = normalize(A0) * r0;
	ellipseMinor = normalize(A1) * r1;
}

vec2 VectorToSlope(vec3 v)
{
	return vec2(-v.x / v.z, -v.y / v.z);
}

vec3 SlopeToVector(vec2 s)
{
	float z = 1 / sqrt(s.x * s.x + s.y * s.y + 1);
	float x = s.x * z;
	float y = s.y * z;
	return vec3(x, y, z);
}

vec2 RotateUV(vec2 uv, float rotation, vec2 mid)
{
	return vec2(
		cos(rotation) * (uv.x - mid.x) + sin(rotation) * (uv.y - mid.y) + mid.x,
		cos(rotation) * (uv.y - mid.y) - sin(rotation) * (uv.x - mid.x) + mid.y
		);
}

float BilinearLerp(vec4 values, vec2 valuesLerp)
{
	// Values XY = vec4(00, 01, 10, 11)
	float resultX = lerp(values.x, values.z, valuesLerp.x);
	float resultY = lerp(values.y, values.w, valuesLerp.x);
	float result = lerp(resultX, resultY, valuesLerp.y);
	return result;
}

vec4 BilinearLerpParallel4(vec4 values00, vec4 values01, vec4 values10, vec4 values11, vec4 valuesLerpX, vec4 valuesLerpY)
{
	// Values XY = vec4(00, 01, 10, 11)
	vec4 resultX = lerp(values00, values10, valuesLerpX);
	vec4 resultY = lerp(values01, values11, valuesLerpX);
	vec4 result = lerp(resultX, resultY, valuesLerpY);
	return result;
}

float Remap(float s, float a1, float a2, float b1, float b2)
{
	return b1 + (s - a1) * (b2 - b1) / (a2 - a1);
}

float Remap01To(float s, float b1, float b2)
{
	return b1 + s * (b2 - b1);
}

float RemapTo01(float s, float a1, float a2)
{
	return (s - a1) / (a2 - a1);
}

vec4 RemapTo01(vec4 s, vec4 a1, vec4 a2)
{
	return (s - a1) / (a2 - a1);
}

vec4 RemapTo01(vec4 s, float a1, float a2)
{
	return (s - a1) / (a2 - a1);
}

vec3 GetBarycentricWeights(vec2 p, vec2 a, vec2 b, vec2 c)
{
	/*vec2 v0 = b - a;
	vec2 v1 = c - a;
	vec2 v2 = p - a;
	float d00 = dot(v0, v0);
	float d01 = dot(v0, v1);
	float d11 = dot(v1, v1);
	float d20 = dot(v2, v0);
	float d21 = dot(v2, v1);
	float denom = d00 * d11 - d01 * d01;
	float v = (d11 * d20 - d01 * d21) / denom;
	float w = (d00 * d21 - d01 * d20) / denom;
	float u = 1.0 - v - w;
	return vec3(u, v, w);*/

	vec2 v0 = b - a;
	vec2 v1 = c - a;
	vec2 v2 = p - a;
	float den = v0.x * v1.y - v1.x * v0.y;
	float v = (v2.x * v1.y - v1.x * v2.y) / den;
	float w = (v0.x * v2.y - v2.x * v0.y) / den;
	float u = 1.0f - v - w;
	return vec3(u, v, w);
}

vec4 GetBarycentricWeightsTetrahedron(vec3 p, vec3 v1, vec3 v2, vec3 v3, vec3 v4)
{
	vec3 c11 = v1 - v4, c21 = v2 - v4, c31 = v3 - v4, c41 = v4 - p;

	vec2 m1 = c31.yz / c31.x;
	vec2 c12 = c11.yz - c11.x * m1, c22 = c21.yz - c21.x * m1, c32 = c41.yz - c41.x * m1;

	vec4 uvwk = vec4(0.0);
	float m2 = c22.y / c22.x;
	uvwk.x = (c32.x * m2 - c32.y) / (c12.y - c12.x * m2);
	uvwk.y = -(c32.x + c12.x * uvwk.x) / c22.x;
	uvwk.z = -(c41.x + c21.x * uvwk.y + c11.x * uvwk.x) / c31.x;
	uvwk.w = 1.0 - uvwk.z - uvwk.y - uvwk.x;

	return uvwk;
}

/* // unpackHalf2x16 is an OpenGL 4.20 feature
void UnpackFloat(float inputFloat, out float a, out float b)
{
	uint uintInput = asuint(inputFloat);
	vec2 unpacked = unpackHalf2x16(uintInput);
	a = unpacked.x;
	b = unpacked.y;
}

void UnpackFloatParallel4(vec4 inputFloat, out vec4 a, out vec4 b)
{
	uvec4 uintInput = asuint(inputFloat);
	vec2 unpackedX = unpackHalf2x16(uintInput.x);
	vec2 unpackedY = unpackHalf2x16(uintInput.y);
	vec2 unpackedZ = unpackHalf2x16(uintInput.z);
	vec2 unpackedW = unpackHalf2x16(uintInput.w);
	a = vec4(unpackedX.x, unpackedY.x, unpackedZ.x, unpackedW.x);
	b = vec4(unpackedX.y, unpackedY.y, unpackedZ.y, unpackedW.y);
}
*/


//=======================================================================================
// GLINTS TEST NOVEMBER 2022
//=======================================================================================
/*void CustomRand4Texture(vec2 slope, vec2 slopeRandOffset, out vec4 outUniform, out vec4 outGaussian, out vec2 slopeLerp)
{
	ivec2 size = uGlint2023NoiseMapSize.rr;
	vec2 slope2 = abs(slope) / uMicrofacetRoughness;
	slope2 = slope2 + (slopeRandOffset * size);
	slopeLerp = fract(slope2);
	ivec2 slopeCoord = ivec2(floor(slope2)) % size;

	vec4 packedRead = uGlint2023NoiseMap[slopeCoord];
	UnpackFloatParallel4(packedRead, outUniform, outGaussian);
}*/

void CustomRand4Texture(vec2 slope, vec2 slopeRandOffset, out vec4 outUniform, out vec4 outGaussian, out vec2 slopeLerp) {
	ivec2 size = ivec2(4096);
	vec2 slope2 = abs(slope) / uMicrofacetRoughness;
	slope2 = slope2 + (slopeRandOffset * size);
	slopeLerp = fract(slope2);
	ivec2 slopeCoord = ivec2(floor(slope2)) % size;
	uvec2 uSlopeCoord = uvec2(slopeCoord);

	outUniform = pcg4dFloat(uvec4(uSlopeCoord.xy, uSlopeCoord.yx + 4096U));
	outGaussian = pcg4dFloat(uvec4(uSlopeCoord.yx + 8192U, slope.xy + 16384U));
}

// This performs  4x binomial Samples per call
// This is called 3x per vertex of the tetrahedron (uv triangle)
// The tetrahedron has 4 vertices
// So 4x3x4 = 48x binomial samples per pixel
float GenerateAngularBinomialValueForSurfaceCell(vec4 randB, vec4 randG, vec2 slopeLerp, float footprintOneHitProba, float binomialSmoothWidth, float footprintMean, float footprintSTD, float microfacetCount)
{
	vec4 gating;
	// ? What is the binomial smooth width?
	if (binomialSmoothWidth > 0.0000001)
		gating = saturate(RemapTo01(randB, footprintOneHitProba + binomialSmoothWidth, footprintOneHitProba - binomialSmoothWidth));
	else
		gating = mix(vec4(0.0), vec4(1.0), lessThan(randB, vec4(footprintOneHitProba)));

	vec4 gauss = randG * footprintSTD + footprintMean;
	gauss = clamp(floor(gauss), 0, microfacetCount);
	vec4 results = gating * (1.0 + gauss);
	float result = BilinearLerp(results, slopeLerp);
	return result;
}

float SampleGlintGridSimplex(vec2 uv, uint gridSeed, vec2 slope, float footprintArea, float targetNDF, float gridWeight)
{
	// Get surface space glint simplex grid cell
	const mat2 gridToSkewedGrid = mat2(1.0, -0.57735027, 0.0, 1.15470054);
	vec2 skewedCoord = mul(gridToSkewedGrid, uv);
	ivec2 baseId = ivec2(floor(skewedCoord));
	vec3 temp = vec3(fract(skewedCoord), 0.0);
	temp.z = 1.0 - temp.x - temp.y;
	float s = step(0.0, -temp.z);
	float s2 = 2.0 * s - 1.0;
	ivec2 glint0 = baseId + ivec2(s, s);
	ivec2 glint1 = baseId + ivec2(s, 1.0 - s);
	ivec2 glint2 = baseId + ivec2(1.0 - s, s);
	vec3 barycentrics = vec3(-temp.z * s2, s - temp.y * s2, s - temp.x * s2);

	GDEBUG_uvTriangles(barycentrics);

	// Generate per surface cell random numbers
	vec3 rand0 = pcg3dFloat(uvec3(glint0 + 2147483648, gridSeed)); // TODO : optimize away manual seeds
	vec3 rand1 = pcg3dFloat(uvec3(glint1 + 2147483648, gridSeed));
	vec3 rand2 = pcg3dFloat(uvec3(glint2 + 2147483648, gridSeed));

	// Get per surface cell per slope cell random numbers
	vec4 rand0SlopesB, rand1SlopesB, rand2SlopesB, rand0SlopesG, rand1SlopesG, rand2SlopesG;
	vec2 slopeLerp0, slopeLerp1, slopeLerp2;
	CustomRand4Texture(slope, rand0.yz, rand0SlopesB, rand0SlopesG, slopeLerp0);
	CustomRand4Texture(slope, rand1.yz, rand1SlopesB, rand1SlopesG, slopeLerp1);
	CustomRand4Texture(slope, rand2.yz, rand2SlopesB, rand2SlopesG, slopeLerp2);

	// Compute microfacet count with randomization
	vec3 logDensityRand = clamp(sampleNormalDistribution(vec3(rand0.x, rand1.x, rand2.x), uLogMicrofacetDensity, uDensityRandomization), 0.0, 50.0); // TODO : optimize sampleNormalDist
	vec3 microfacetCount = max(vec3(0.0), vec3(footprintArea) * exp(logDensityRand));
	vec3 microfacetCountBlended = microfacetCount * gridWeight;

	// Compute binomial properties
	float hitProba = uMicrofacetRoughness * targetNDF; // probability of hitting desired half vector in NDF distribution
	vec3 footprintOneHitProba = (1.0 - pow(1.0 - vec3(hitProba), microfacetCountBlended)); // probability of hitting at least one microfacet in footprint
	vec3 footprintMean = (microfacetCountBlended - 1.0) * vec3(hitProba); // Expected value of number of hits in the footprint given already one hit
	vec3 footprintSTD = sqrt((microfacetCountBlended - 1.0) * vec3(hitProba) * (1.0 - vec3(hitProba))); // Standard deviation of number of hits in the footprint given already one hit
	// soft if 
	// TODO: uniform to switch between soft and hard
	vec3 binomialSmoothWidth = 0.1 * clamp(footprintOneHitProba * 10, 0.0, 1.0) * clamp((1.0 - footprintOneHitProba) * 10, 0.0, 1.0); // vec3(0.0)

	// Generate numbers of reflecting microfacets
	float result0, result1, result2;
	result0 = GenerateAngularBinomialValueForSurfaceCell(rand0SlopesB, rand0SlopesG, slopeLerp0, footprintOneHitProba.x, binomialSmoothWidth.x, footprintMean.x, footprintSTD.x, microfacetCountBlended.x);
	result1 = GenerateAngularBinomialValueForSurfaceCell(rand1SlopesB, rand1SlopesG, slopeLerp1, footprintOneHitProba.y, binomialSmoothWidth.y, footprintMean.y, footprintSTD.y, microfacetCountBlended.y);
	result2 = GenerateAngularBinomialValueForSurfaceCell(rand2SlopesB, rand2SlopesG, slopeLerp2, footprintOneHitProba.z, binomialSmoothWidth.z, footprintMean.z, footprintSTD.z, microfacetCountBlended.z);

	// Interpolate result for glint grid cell
	vec3 results = vec3(result0, result1, result2) / microfacetCount.xyz;
	float result = dot(results, barycentrics);
	return result;
}
															   // ! weird
void GetAnisoCorrectingGridTetrahedron(bool centerSpecialCase, /*inout*/ float thetaBinLerp, float ratioLerp, float lodLerp, out vec3 p0, out vec3 p1, out vec3 p2, out vec3 p3)
{
	if (centerSpecialCase == true) // SPECIAL CASE (no anisotropy, center of blending pattern, different triangulation)
	{
		vec3 a = vec3(0, 1, 0);
		vec3 b = vec3(0, 0, 0);
		vec3 c = vec3(1, 1, 0);
		vec3 d = vec3(0, 1, 1);
		vec3 e = vec3(0, 0, 1);
		vec3 f = vec3(1, 1, 1);
		if (lodLerp > 1.0 - ratioLerp) // Upper pyramid
		{
			if (RemapTo01(lodLerp, 1.0 - ratioLerp, 1.0) > thetaBinLerp) // Left-up tetrahedron (a, e, d, f)
			{
				p0 = a; p1 = e; p2 = d; p3 = f;
			}
			else // Right-down tetrahedron (f, e, c, a)
			{
				p0 = f; p1 = e; p2 = c; p3 = a;
			}
		}
		else // Lower tetrahedron (b, a, c, e)
		{
			p0 = b; p1 = a; p2 = c; p3 = e;
		}
	}
	else // NORMAL CASE
	{
		// 		 vec3(theta, aniso, area)
		// bottom
		vec3 a = vec3(0, 1, 0);
		vec3 b = vec3(0, 0, 0);
		vec3 c = vec3(0.5, 1, 0);
		vec3 d = vec3(1, 0, 0);
		vec3 e = vec3(1, 1, 0);
		// top
		vec3 f = vec3(0, 1, 1);
		vec3 g = vec3(0, 0, 1);
		vec3 h = vec3(0.5, 1, 1);
		vec3 i = vec3(1, 0, 1);
		vec3 j = vec3(1, 1, 1);
		if (thetaBinLerp < 0.5 && thetaBinLerp * 2.0 < ratioLerp) // Prism A
		{
			if (lodLerp > 1.0 - ratioLerp) // Upper pyramid
			{
				if (RemapTo01(lodLerp, 1.0 - ratioLerp, 1.0) > RemapTo01(thetaBinLerp * 2.0, 0.0, ratioLerp)) // Left-up tetrahedron (a, f, h, g)
				{
					p0 = a; p1 = f; p2 = h; p3 = g;
				}
				else // Right-down tetrahedron (c, a, h, g)
				{
					p0 = c; p1 = a; p2 = h; p3 = g;
				}
			}
			else // Lower tetrahedron (b, a, c, g)
			{
				p0 = b; p1 = a; p2 = c; p3 = g;
			}
		}
		else if (1.0 - ((thetaBinLerp - 0.5) * 2.0) > ratioLerp) // Prism B
		{
			if (lodLerp < 1.0 - ratioLerp) // Lower pyramid
			{
				if (RemapTo01(lodLerp, 0.0, 1.0 - ratioLerp) > RemapTo01(thetaBinLerp, 0.5 - (1.0 - ratioLerp) * 0.5, 0.5 + (1.0 - ratioLerp) * 0.5)) // Left-up tetrahedron (b, g, i, c)
				{
					p0 = b; p1 = g; p2 = i; p3 = c;
				}
				else // Right-down tetrahedron (d, b, c, i)
				{
					p0 = d; p1 = b; p2 = c; p3 = i;
				}
			}
			else // Upper tetrahedron (c, g, h, i)
			{
				p0 = c; p1 = g; p2 = h; p3 = i;
			}
		}
		else // Prism C
		{
			if (lodLerp > 1.0 - ratioLerp) // Upper pyramid
			{
				if (RemapTo01(lodLerp, 1.0 - ratioLerp, 1.0) > RemapTo01((thetaBinLerp - 0.5) * 2.0, 1.0 - ratioLerp, 1.0)) // Left-up tetrahedron (c, j, h, i)
				{
					p0 = c; p1 = j; p2 = h; p3 = i;
				}
				else // Right-down tetrahedron (e, i, c, j)
				{
					p0 = e; p1 = i; p2 = c; p3 = j;
				}
			}
			else // Lower tetrahedron (d, e, c, i)
			{
				p0 = d; p1 = e; p2 = c; p3 = i;
			}
		}
	}

	return;
}

float SampleGlints2023NDF(vec3 localHalfVector, float targetNDF, float maxNDF, vec2 uv, vec2 duvdx, vec2 duvdy)
{
	// ACCURATE PIXEL FOOTPRINT ELLIPSE
	vec2 ellipseMajor, ellipseMinor;
	GetGradientEllipse(duvdx, duvdy, ellipseMajor, ellipseMinor);
	float ellipseRatio = length(ellipseMajor) / length(ellipseMinor);

	// SHARED GLINT NDF VALUES
	float halfScreenSpaceScaler = uScreenSpaceScale * 0.5;
	// ! Unnecessary square roots
	float footprintArea = length(ellipseMajor) * halfScreenSpaceScaler * length(ellipseMinor) * halfScreenSpaceScaler * 4.0;
	vec2 slope = localHalfVector.xy; // Orthogrtaphic slope projected grid
	float rescaledTargetNDF = targetNDF / maxNDF;

	// MANUAL LOD COMPENSATION
	float lod = log2(length(ellipseMinor) * halfScreenSpaceScaler);
	float lod0 = int(lod); //lod >= 0.0 ? (int)(lod) : (int)(lod - 1.0);
	float lod1 = lod0 + 1;
	float divLod0 = exp2(lod0);
	float divLod1 = exp2(lod1);
	// ! this is not a real lerp but a logarithmic lerp
	float lodLerp = fract(lod);
	// ! This leads to artifacts! Why?
	// float lodLerp = RemapTo01(length(ellipseMinor) * halfScreenSpaceScaler, divLod0, divLod1);
	// ! This is not the real area just the minor length squared
	float footprintAreaLOD0 = divLod0 * divLod0;
	float footprintAreaLOD1 = divLod1 * divLod1;

	// MANUAL ANISOTROPY RATIO COMPENSATION

	float ratio0 = max(pow(2.0, int(log2(ellipseRatio))), 1.0);
	float ratio1 = ratio0 * 2.0;
	float ratioLerp = clamp(Remap(ellipseRatio, ratio0, ratio1, 0.0, 1.0), 0.0, 1.0);

	// MANUAL ANISOTROPY ROTATION COMPENSATION
	vec2 v1 = vec2(0.0, 1.0);
	vec2 v2 = normalize(ellipseMajor);
	float theta = atan2(v1.x * v2.y - v1.y * v2.x, v1.x * v2.x + v1.y * v2.y) * RAD2DEG;
	float thetaGrid = 90.0 / max(ratio0, 2.0);
	float thetaBin = int((theta / thetaGrid)) * thetaGrid;
	thetaBin = thetaBin + (thetaGrid / 2.0);
	float thetaBin0 = theta < thetaBin ? thetaBin - thetaGrid / 2.0 : thetaBin;
	float thetaBinH = thetaBin0 + thetaGrid / 4.0;
	float thetaBin1 = thetaBin0 + thetaGrid / 2.0;
	float thetaBinLerp = Remap(theta, thetaBin0, thetaBin1, 0.0, 1.0);
	thetaBin0 = thetaBin0 <= 0.0 ? 180.0 + thetaBin0 : thetaBin0;

	// TETRAHEDRONIZATION OF ROTATION + RATIO + LOD GRID
	bool centerSpecialCase = (ratio0 == 1.0);
	// ? Why this complicated indexing process?
	vec2 divLods = vec2(divLod0, divLod1);
	// ! This is just divLods squared
	vec2 footprintAreas = vec2(footprintAreaLOD0, footprintAreaLOD1);
	vec2 ratios = vec2(ratio0, ratio1);
	vec4 thetaBins = vec4(thetaBin0, thetaBinH, thetaBin1, 0.0); // added 0.0 for center singularity case
	vec3 tetraA, tetraB, tetraC, tetraD;
	GetAnisoCorrectingGridTetrahedron(centerSpecialCase, thetaBinLerp, ratioLerp, lodLerp, tetraA, tetraB, tetraC, tetraD);
	// ! This is very important to avoid artifacts
	// ? Why? because in the center case the ground pentagon loses one vertex
	if (centerSpecialCase == true) // Account for center singularity in barycentric computation
		thetaBinLerp = Remap01To(thetaBinLerp, 0.0, ratioLerp);
	vec4 tetraBarycentricWeights = GetBarycentricWeightsTetrahedron(vec3(thetaBinLerp, ratioLerp, lodLerp), tetraA, tetraB, tetraC, tetraD); // Compute barycentric coordinates within chosen tetrahedron

	GDEBUG_area(vec3(footprintArea * 4000.0));
    GDEBUG_theta(angleToRGB(theta * DEG2RAD));
    GDEBUG_aniso(vec3(1.0 / ellipseRatio));
    GDEBUG_major(normalToRGB(normalize(ellipseMajor)));

	GDEBUG_grid(vec3(footprintAreaLOD0 * 1000.0, 1.0 / ratio0, thetaBin0 / 360.0));
    GDEBUG_lodWeight(vec3(lodLerp));
    GDEBUG_anisoWeight(vec3(ratioLerp));
    GDEBUG_thetaWeight(vec3(thetaBinLerp));
    GDEBUG_centerCase(boolToRGB(centerSpecialCase));
	GDEBUG_baryA(vec3(tetraBarycentricWeights.x));
	GDEBUG_baryB(vec3(tetraBarycentricWeights.y));
	GDEBUG_baryC(vec3(tetraBarycentricWeights.z));
	GDEBUG_baryD(vec3(tetraBarycentricWeights.w));

	// PREPARE NEEDED ROTATIONS
	tetraA.x *= 2; tetraB.x *= 2; tetraC.x *= 2; tetraD.x *= 2;
	ivec3 iTetraA = ivec3(tetraA);
	ivec3 iTetraB = ivec3(tetraB);
	ivec3 iTetraC = ivec3(tetraC);
	ivec3 iTetraD = ivec3(tetraD);
	if (centerSpecialCase == true) // Account for center singularity (if center vertex => no rotation)
	{
		iTetraA.x = (iTetraA.y == 0) ? 3 : iTetraA.x;
		iTetraB.x = (iTetraB.y == 0) ? 3 : iTetraB.x;
		iTetraC.x = (iTetraC.y == 0) ? 3 : iTetraC.x;
		iTetraD.x = (iTetraD.y == 0) ? 3 : iTetraD.x;
	}
	GDEBUG_uvGrid(checkerboard(uv, 100.0));
	vec2 uvRotA = RotateUV(uv, thetaBins[iTetraA.x] * DEG2RAD, vec2(0.0));
	vec2 uvRotB = RotateUV(uv, thetaBins[iTetraB.x] * DEG2RAD, vec2(0.0));
	vec2 uvRotC = RotateUV(uv, thetaBins[iTetraC.x] * DEG2RAD, vec2(0.0));
	vec2 uvRotD = RotateUV(uv, thetaBins[iTetraD.x] * DEG2RAD, vec2(0.0));

	// SAMPLE GLINT GRIDS
	uint gridSeedA = asuint(HashWithoutSine13(vec3(log2(divLods[iTetraA.z]), mod(thetaBins[iTetraA.x], 360), ratios[iTetraA.y])) * 4294967296.0);
	GDEBUG_seedA(vec3(float(gridSeedA) / 4294967296.0));
	uint gridSeedB = asuint(HashWithoutSine13(vec3(log2(divLods[iTetraB.z]), mod(thetaBins[iTetraB.x], 360), ratios[iTetraB.y])) * 4294967296.0);
	uint gridSeedC = asuint(HashWithoutSine13(vec3(log2(divLods[iTetraC.z]), mod(thetaBins[iTetraC.x], 360), ratios[iTetraC.y])) * 4294967296.0);
	uint gridSeedD = asuint(HashWithoutSine13(vec3(log2(divLods[iTetraD.z]), mod(thetaBins[iTetraD.x], 360), ratios[iTetraD.y])) * 4294967296.0);
	float sampleA = SampleGlintGridSimplex(uvRotA / divLods[iTetraA.z] / vec2(1.0, ratios[iTetraA.y]), gridSeedA, slope, ratios[iTetraA.y] * footprintAreas[iTetraA.z], rescaledTargetNDF, tetraBarycentricWeights.x);
	float sampleB = SampleGlintGridSimplex(uvRotB / divLods[iTetraB.z] / vec2(1.0, ratios[iTetraB.y]), gridSeedB, slope, ratios[iTetraB.y] * footprintAreas[iTetraB.z], rescaledTargetNDF, tetraBarycentricWeights.y);
	float sampleC = SampleGlintGridSimplex(uvRotC / divLods[iTetraC.z] / vec2(1.0, ratios[iTetraC.y]), gridSeedC, slope, ratios[iTetraC.y] * footprintAreas[iTetraC.z], rescaledTargetNDF, tetraBarycentricWeights.z);
	float sampleD = SampleGlintGridSimplex(uvRotD / divLods[iTetraD.z] / vec2(1.0, ratios[iTetraD.y]), gridSeedD, slope, ratios[iTetraD.y] * footprintAreas[iTetraD.z], rescaledTargetNDF, tetraBarycentricWeights.w);
	GDEBUG_uvGridCompensated(checkerboard(uvRotD / divLods[iTetraD.z] / vec2(1.0, ratios[iTetraD.y])));
	return (sampleA + sampleB + sampleC + sampleD) * (1.0 / uMicrofacetRoughness) * maxNDF;
}