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
