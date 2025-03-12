#version 300 es

// Define a constant array of vec2 positions for our quad
const vec2 vertices[4] = vec2[4](
    vec2(-1.0, 1.0), // Top-left
    vec2(-1.0, -1.0), // Bottom-left
    vec2(1.0, 1.0), // Top-right
    vec2(1.0, -1.0) // Bottom-right
);

// Define UVs array matching the Metal implementation
const vec2 uvs[4] = vec2[4](
    vec2(0.0, 0.0), // Top-left
    vec2(0.0, 1.0), // Bottom-left
    vec2(1.0, 0.0), // Top-right
    vec2(1.0, 1.0) // Bottom-right
);

// Define the percentage of screen to use
const float fullScreenPercentage = 0.75;

// Output varying for texture coordinates
out vec2 texCoord;

void main() {
    // Get the vertex position from our constant array using gl_VertexID
    vec2 position = vertices[gl_VertexID] * fullScreenPercentage;
    gl_Position = vec4(position, 0.0, 1.0);

    // Use the UVs directly from our constant array
    texCoord = uvs[gl_VertexID];
}
