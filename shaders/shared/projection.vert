#version 330 core

layout (location = 0) in vec3 _position;
layout (location = 1) in vec2 _uv;
layout (location = 2) in vec3 _normal;
layout (location = 3) in vec3 _tangent;
layout (location = 4) in vec3 _bitangent;

out VertexData {
    vec2 uv;
    vec3 worldPosition;
    vec3 worldNormal;
    vec3 tangentLightDir;
    vec3 tangentViewDir;
    vec3 tangentPosition;
    vec3 tangentViewPosition;
    vec3 worldTangent;
};

#include "shared/uniforms.glsl"
#line 22 107

/**
 * Applies the model, view, and projection matrices to a mesh
 */
void main() {

    // apply perspective transformation
    gl_Position = uLocalToClip * vec4(_position, 1.0);

    // pass uv coordinates to fragment shader
    uv = _uv;

    // transform normals and tangents to world space
    worldPosition = (uLocalToWorld * vec4(_position, 1.0)).xyz;
    worldNormal = normalize((uLocalToWorld * vec4(_normal, 0.0)).xyz);
    worldTangent = normalize((uLocalToWorld * vec4(_tangent, 0.0)).xyz);
    // Gram-Schmidt orthogonalization
    worldTangent = normalize(worldTangent - dot(worldTangent, worldNormal) * worldNormal);
    vec3 worldBitangent = cross(worldNormal, worldTangent);

    // Build the tangent space
    mat3 tangentToWorld = mat3(worldTangent, worldBitangent, worldNormal);
    mat3 worldToTangent = transpose(tangentToWorld); // transpose instead of inverse because tangentToWorld is orthonormal

    // Calculate light and view directions in world space
    vec3 worldLightDir = uLightDir;
    vec3 worldViewDir = normalize(uCameraPosition - worldPosition);

    // Transform light and view directions to tangent space to enable lighting calculations in tangent space
    tangentLightDir = worldToTangent * worldLightDir;
    tangentViewDir = worldToTangent * worldViewDir;
    tangentPosition = worldToTangent * worldPosition;
    tangentViewPosition = worldToTangent * uCameraPosition;
}