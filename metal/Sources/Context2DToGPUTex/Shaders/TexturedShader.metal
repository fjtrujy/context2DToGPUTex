#include <metal_stdlib>
using namespace metal;

constant const float2 vertices[4] = {
    float2(-1.0,  1.0),
    float2(-1.0, -1.0),
    float2(1.0,  1.0),
    float2(1.0, -1.0),
};

constant const float2 uvs[4] = {
    float2(0.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(1.0, 1.0),
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertex_main(const ushort vid [[ vertex_id ]]) {
    VertexOut out;
    out.position = float4(vertices[vid], 0.0f, 1.0f);
    out.texCoord = uvs[vid];
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    return texture.sample(s, in.texCoord);
}
