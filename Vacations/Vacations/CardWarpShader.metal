//
//  CardWarpShader.metal
//  Vacations
//
//  SwiftUI distortion shader used by the trip-card entrance animation.
//  Bends the rendered card along a sinusoidal arc so the entrance feels
//  like a curved sheet flying forward, not a flat plane.
//
//  Inputs:
//    position  current output pixel coordinate (pt)
//    size      view size (pt)
//    amount    0..1, how strongly to apply the warp (0 = identity)
//
//  Output: source position to sample. We shift x as a function of y so
//  the middle of the card visibly bows sideways at full amount and
//  smoothly resolves to flat at amount = 0.
//

#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] float2 cardWarp(float2 position, float2 size, float amount) {
    float ny = position.y / size.y;             // 0 at top, 1 at bottom
    // Anchor at bottom: bow is maximum at the top edge (ny = 0) and tapers
    // to zero at the bottom edge (ny = 1). cos(ny · π/2) is 1 at top, 0 at
    // bottom — gives a clean "bottom planted, top curling forward" look.
    float bow = cos(ny * 1.5707963);
    float maxShift = 28.0;
    float xShift = amount * bow * maxShift;
    return float2(position.x - xShift, position.y);
}

//  Roll-up page curl for the days-left calendar sheet.
//
//  The sheet rolls around a cylinder that sweeps up the page. The roll line
//  is tilted (slope) so the LEFT edge rolls first — the curl travels toward
//  the top-left. Pixels above the line are untouched; a band of height
//  `rollH` below it samples compressed content (the wrap around the
//  cylinder); everything past the band has already been rolled away and
//  samples off-layer (transparent).
[[ stitchable ]] float2 pageCurl(float2 position, float2 size,
                                 float progress, float rollH) {
    float slope = 0.35;                  // tilt: left edge leads the roll
    float k = 3.0;                       // wrap compression factor
    float start = size.y + slope * size.x;   // line fully below the sheet
    float endv  = -rollH * k;                // line fully above (band gone too)
    float rollPos = start + (endv - start) * progress;
    float lineY = rollPos - slope * (size.x - position.x);
    float d = position.y - lineY;
    if (d < 0.0) return position;                              // still flat
    if (d < rollH) return float2(position.x, lineY + d * k);   // on the roll
    return float2(-1e4, -1e4);                                 // rolled away
}

//  Fine film grain for the trip-page header gradient. A per-pixel hash
//  nudges the color up or down a touch so the wash reads as paper-like
//  texture instead of a flat digital ramp.
[[ stitchable ]] half4 grain(float2 position, half4 color, float intensity) {
    float n = fract(sin(dot(position, float2(12.9898, 78.233))) * 43758.5453);
    half g = half((n - 0.5) * intensity);
    return half4(color.rgb + g * color.a, color.a);
}
