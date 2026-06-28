// card_warp.frag
//
// Flutter port of CardWarpShader.metal (TripAnnouncementViewV2 entrance).
// Bends the rendered card along a sinusoidal arc, bottom-anchored: the top edge
// bows sideways by up to 28pt at amount=1, tapering to 0 at the bottom edge and
// resolving to flat at amount=0. See FLUTTER_PORT_SPEC.md §7 / §13.5.
//
// The Metal shader returns the SOURCE position to sample for each destination
// pixel: (position.x - xShift, position.y). We reproduce that and sample the
// child texture at the normalized source coordinate.

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // view size (pt)
uniform float uAmount;  // 0..1 warp strength
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    vec2 pos = FlutterFragCoord().xy;
    float ny = pos.y / uSize.y;             // 0 at top, 1 at bottom
    float bow = cos(ny * 1.5707963);        // 1 at top, 0 at bottom (pi/2)
    float maxShift = 28.0;
    float xShift = uAmount * bow * maxShift;
    // The AnimatedSampler texture has a bottom-left origin, so flip Y when
    // sampling to keep the card upright (otherwise it renders inverted until
    // the warp ends and the shader is removed).
    vec2 uv = vec2((pos.x - xShift) / uSize.x, 1.0 - pos.y / uSize.y);
    fragColor = texture(uTexture, uv);
}
