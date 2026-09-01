import Foundation

/// The coins cinematic is maintained in **two variants**, so a direction can be
/// explored without losing the other.
///
/// - ``classic`` — version 1. No particle cloud: the
///   amount simply fades, and the bottom carries the three gradient circles of
///   Figma 6396:9357, which idle and then leave upward in one fast move while
///   the content scales back and springs out again.
/// - ``refined`` — **version 2, and the default.** The particle dissolve, and
///   the four-disc aurora that grows until it floods the screen behind a
///   travelling glass beam.
///
/// Both are always built and always runnable — nothing is commented out.
/// Running the app plainly gives `refined`; reach the other with:
///
///     xcrun simctl launch <udid> cards.scapia.Vacations -coinsVariant classic
///
/// Note that the two differ only in the gates below. Everything else — the
/// palette, the layout, the Portugal content, the particle path and colour, and
/// all of the timing — is shared, so a change made outside this enum lands in
/// both. If a change is meant for one variant only, it needs a gate here.
enum CoinsVariant: String {
    case classic
    case refined

    /// Overridable at launch via `-coinsVariant classic`, the same mechanism
    /// `-bookingKind` uses. Unset — which is what a plain Run from Xcode gives
    /// — means `refined`.
    static let active: CoinsVariant = {
        if let raw = UserDefaults.standard.string(forKey: "coinsVariant"),
           let variant = CoinsVariant(rawValue: raw) {
            return variant
        }
        return .refined
    }()

    // MARK: Behaviour gates

    /// Whether the amount breaks into the rising particle cloud.
    ///
    /// This is the fork the two variants are really built around, and it decides
    /// three things at once, because the other two only exist to serve the
    /// cloud:
    ///
    /// - the cloud itself;
    /// - the anticipation lift, which is a wind-up into the glyphs breaking
    ///   apart and reads as an aimless drift without them;
    /// - the mask sweep that eats the number bottom-to-top, which is the
    ///   hand-off of each row of glyphs to the particles born from it.
    ///
    /// With it off the number simply fades where it stands, over the same
    /// `dissolveProgress` curve, so the beat still lands at the same moment.
    var showsParticles: Bool { self == .refined }

    /// How the amount leaves. Off in both variants, so both are eaten
    /// bottom-to-top by the mask sweep as the glyphs convert to particles —
    /// the original behaviour.
    ///
    /// The alternative it selects, ``SkewLift`` — shear over, lift and shrink
    /// away — is still wired at the call site and runs as an identity transform
    /// while this is false. Return `self == .refined` to bring it back; it only
    /// makes sense with ``showsParticles`` off, since the mask has to be held
    /// open for it and there would then be nothing to hand the glyphs to.
    var numberExitsBySkew: Bool { false }

    /// Which backdrop the bottom of the screen carries.
    ///
    /// `classic` uses the three gradient-filled circles of Figma 6396:9357,
    /// which sit at the bottom, drift, and then leave upward in one fast move.
    /// `refined` keeps the four flat discs that grow and flood the screen.
    var usesBottomBloom: Bool { self == .classic }

    /// Whether the coin clip drops out while the particle cloud is in the air.
    /// The plumes rise straight through the artwork and the two compete for the
    /// same space, so the clip fades away as they leave and returns just as the
    /// last of them reach the pill.
    var artFadesForParticles: Bool { self == .refined }

    /// How far past the top of the screen the aurora keeps climbing. Larger
    /// values push the outer bands off and let the innermost disc — the yellow
    /// — take the screen.
    var auroraOvershoot: CGFloat { self == .refined ? 1700 : 412 }

    /// Whether a disc's blur grows in step with the disc (`classic`) or on its
    /// square root (`refined`). At refined's much larger growth a linear blur
    /// reaches ~218pt — wide enough that the innermost disc never reaches full
    /// opacity and the band beneath keeps showing through it, so the yellow
    /// could not take the screen however far the sweep was pushed.
    var blurScalesLinearly: Bool { self == .classic }

    /// How steeply the travelling beam's glass shades its own shoulders.
    ///
    /// `classic` uses 1, which is the header reveal's original response. The
    /// `refined` field runs to pure white at the bottom, and white light on a
    /// white ground has nowhere to go — additive brightness simply clamps. What
    /// still reads there is the shadow the lens casts on either side of its
    /// crest, so the beam is given form by deepening that rather than by trying
    /// to make it brighter.
    var beamShading: CGFloat { self == .refined ? 1.9 : 1.0 }

    /// Opacity of the drawn band's white core. This is the one part of the beam
    /// that renders on iOS 16 as well, since the shader below it is gated to 17+.
    var beamCoreOpacity: Double { self == .refined ? 0.85 : 0.55 }

    /// Where the halo is anchored: 0 on the origin, 1 on the travelling crest.
    ///
    /// `refined` rides the crest, matching NameDrop, where the hot core sits at
    /// the contact point the light is pouring out of. `classic` keeps the
    /// origin anchor the header reveal uses.
    var beamHaloAtCrest: CGFloat { self == .refined ? 1 : 0 }

    /// Peak halo intensity. On the crest it can burn at NameDrop strength —
    /// blown out to white with a broad falloff — because it travels with the
    /// beam. Anchored on the origin the same value would flood the screen from
    /// below, which is why `classic` runs it at a fraction.
    var beamHaloStrength: CGFloat { self == .refined ? 1.3 : 0.18 }

    /// How far the halo spills. Tied to the crest this is a fixed radius around
    /// the band rather than something that grows with the sweep.
    var beamHaloRadius: CGFloat { self == .refined ? 380 : 0 }
}
