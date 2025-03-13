@group(0) @binding(0) var textureSampler: sampler;
@group(0) @binding(1) var texture: texture_2d<f32>;

@fragment
fn main(@location(0) texCoord: vec2f) -> @location(0) vec4f {
    return textureSample(texture, textureSampler, texCoord);
} 