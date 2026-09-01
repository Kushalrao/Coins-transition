import SwiftUI

/// A single thick band of glass at `radius` from `center`, refracting whatever
/// it passes over and carrying real light along its arc.
///
/// One band — no trailing ripple train, so what travels up the screen is a
/// single beam. The strength comes from the light model rather than from
/// stacking more rings: the multiplicative blow-out, the specular riding the
/// content relief, and the halo running ahead of the crest. See
/// `GlassWave.metal`.
///
/// Apply this **across the whole surface**, not inside the mask that reveals
/// the aurora. The band straddles the boundary — half of it lies outside the
/// revealed area — so masking first throws away the part that makes it read as
/// a lens.
///
/// The effect samples rendered content, so it cannot run over an
/// `AVPlayerLayer`: drop the modifier from the tree entirely in that case
/// rather than passing `isEnabled: false`, which is not enough to keep the
/// video off the raster path.
struct AuroraBeamEffect: ViewModifier {
    /// Centre the arc is struck from — shared with the aurora discs, below the
    /// bottom edge, so the band curves the same way they do.
    var center: CGPoint
    /// Where the arc currently sits.
    var radius: CGFloat
    /// Half-width of the band. The glass spans `radius ± band`. Deliberately
    /// far wider than the 54 the header reveal uses: that band crosses a
    /// 340pt header, this one sweeps a whole screen and wants thickness.
    var band: CGFloat = 170
    /// Peak radial displacement through the band, in points.
    var refraction: CGFloat = 46
    /// How hard the band blows out what it passes over.
    var glow: CGFloat = 0.95
    /// How far apart the luminance taps sit when reading relief off the content.
    var reliefOffset: CGFloat = 3
    /// How strongly the content's own relief tilts the glass surface.
    var reliefStrength: CGFloat = 1.6
    /// Brightness of the highlight crawling over that relief.
    var specularStrength: CGFloat = 0.55
    /// How far the halo spills from the origin. It reaches past the crest.
    var bloomRadius: CGFloat = 240
    /// How hot the halo burns. 0 turns it off.
    var bloomStrength: CGFloat = 0
    /// How steeply the glass shades its own shoulders. 1 reproduces the header
    /// reveal exactly; higher gives the band form over a field too pale for its
    /// light to register against.
    var shading: CGFloat = 1
    /// 0 anchors the halo on the origin (the header reveal's behaviour); 1 rides
    /// it on the travelling crest, which is the NameDrop contact point.
    var haloAtCrest: CGFloat = 0
    /// Scales the whole beam — refraction, glow, highlight — together. Used to
    /// ease it out so nothing is left mid-flight when the effect is dropped.
    var strength: CGFloat = 1
    /// Where the highlight sits, as a fraction of the radius from the centre.
    /// Negative y puts it above the origin, up near the travelling crest.
    var lightOffset: CGSize = CGSize(width: -0.30, height: -0.35)

    @ViewBuilder
    func body(content: Content) -> some View {
        // iOS 16 has no shader effects, so the beam keeps its light and its
        // travel but loses the refraction — the drawn band in `AuroraBackdrop`
        // is what carries it there.
        if #available(iOS 17.0, *) {
            content.visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.auroraBeam(
                        .float2(proxy.size),
                        .float2(center),
                        .float(radius),
                        .float(band),
                        .float(refraction * strength),
                        .float(glow * strength),
                        .float2(
                            center.x + lightOffset.width * radius,
                            center.y + lightOffset.height * radius
                        ),
                        .float(reliefOffset),
                        .float(reliefStrength * strength),
                        .float(specularStrength * strength),
                        .float(bloomRadius),
                        .float(bloomStrength),
                        .float(shading),
                        .float(haloAtCrest)
                    ),
                    maxSampleOffset: CGSize(
                        width: refraction + reliefOffset + 8,
                        height: refraction + reliefOffset + 8
                    )
                )
            }
        } else {
            content
        }
    }
}

extension View {
    /// Runs a single thick band of glass across this view at `radius` from
    /// `center`, with a halo of the given strength burning at the origin.
    func auroraBeam(
        center: CGPoint,
        radius: CGFloat,
        strength: CGFloat = 1,
        bloomRadius: CGFloat,
        bloomStrength: CGFloat,
        shading: CGFloat = 1,
        haloAtCrest: CGFloat = 0
    ) -> some View {
        modifier(
            AuroraBeamEffect(
                center: center,
                radius: radius,
                bloomRadius: bloomRadius,
                bloomStrength: bloomStrength,
                shading: shading,
                haloAtCrest: haloAtCrest,
                strength: strength
            )
        )
    }
}
