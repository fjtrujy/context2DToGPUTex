struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) texCoord: vec2f,
}

const fullScreenPercentage = 0.75;

const VERTICES = array<vec2<f32>, 4>(
    vec2<f32>(-1.0, -1.0), // Bottom left
    vec2<f32>( 1.0, -1.0), // Bottom right
    vec2<f32>(-1.0,  1.0), // Top left
    vec2<f32>( 1.0,  1.0)  // Top right
);

const UVS = array<vec2<f32>, 4>(
    vec2<f32>(0.0, 1.0), // Bottom left
    vec2<f32>(1.0, 1.0), // Bottom right
    vec2<f32>(0.0, 0.0), // Top left
    vec2<f32>(1.0, 0.0)  // Top right
);

@vertex
fn main(@builtin(vertex_index) VertexIndex: u32) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(VERTICES[VertexIndex] * fullScreenPercentage, 0.0, 1.0);
    output.texCoord = UVS[VertexIndex];
    return output;
} 