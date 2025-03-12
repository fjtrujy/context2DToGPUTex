#version 300 es
precision highp float;

uniform sampler2D u_texture;
in vec2 texCoord;
out vec4 fragColor;

void main() {
    fragColor = texture(u_texture, texCoord);
}
