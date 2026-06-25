//
//  RewardCardView.swift
//  Vacations
//
//  Reward card. All numeric values come from the Figma source so the visual
//  matches at the slot 0 (front) size; child elements scale proportionally
//  via a passed-in `scale` factor when the card is rendered in slots 1 and 2.
//

import SwiftUI

struct RewardCardModel: Identifiable, Equatable {
    let id: UUID
    let title: String
    let imageName: String
    /// Asset name shown in the card header once the deck is unlocked.
    /// Replaces the gift-wrap artwork with a destination photograph.
    let unlockedImageName: String
    /// Aspect/positioning describing how the gift-wrap art is laid into the
    /// card at the **front-slot** geometry (326 × 225). All other slots scale
    /// these values uniformly, so we only have to capture them once per card.
    let artwork: ArtworkLayout

    struct ArtworkLayout: Equatable {
        let width: CGFloat
        let height: CGFloat
        /// Distance from the card's leading edge to the artwork's leading edge.
        /// Negative values mean the artwork bleeds past the card to the left.
        let leftInset: CGFloat
        /// Distance from the card's bottom edge to the artwork's bottom edge.
        /// Negative values mean the artwork bleeds past the card to the bottom.
        let bottomInset: CGFloat
    }
}

extension RewardCardModel {
    /// Reward cards from the Figma frame, listed front-to-back. The first
    /// three are the Figma source set; the remaining five reuse the same
    /// artwork variants so the stack has more entries to scroll through.
    /// All artwork values are expressed at the front-slot reference
    /// (326-wide card). When a card sits in a smaller slot they are scaled
    /// down proportionally so the rendered geometry matches the source.
    static let demo: [RewardCardModel] = [
        // "Stay in Germany"
        // GiftWrap.svg viewBox: 375 × 281.058. In Figma the artwork sits in a
        // 326 × 225 card with `left: -15px`, `bottom: -38px`.
        RewardCardModel(
            id: UUID(),
            title: "Stay in Iceland",
            imageName: "GiftWrap",
            unlockedImageName: "TripIceland",
            artwork: .init(width: 375, height: 281.058, leftInset: -15, bottomInset: -38)
        ),
        // "Experiences in Germany"
        // Experiences.svg viewBox: 334.455 × 324.238. In Figma the artwork is
        // positioned inside a 300.364 × 207.307 card so that its top-left
        // corner sits at (-2.71, -109.63) and it bleeds 7.30px past the
        // bottom edge. Scaled up to the front-slot (×326/300.364 = 1.0853)
        // those numbers become the values below.
        RewardCardModel(
            id: UUID(),
            title: "Experiences in Iceland",
            imageName: "Experiences",
            unlockedImageName: "TripIceland",
            artwork: .init(width: 363.04, height: 351.86, leftInset: -2.94, bottomInset: -7.92)
        ),
        // "Schengen Visa"
        // Schengen.svg viewBox: 254.283 × 246.515. In Figma the artwork sits
        // inside a 228.364 × 157.613 card with top-left at (-2.09, -83.36)
        // and bleeds 5.54px past the bottom. Scaled to the front-slot
        // (×326/228.364 = 1.4276) those become the values below — which
        // happen to converge with the "Experiences" values because both
        // exports show the same gift-wrap motif at proportional crops.
        RewardCardModel(
            id: UUID(),
            title: "Schengen Visa",
            imageName: "Schengen",
            unlockedImageName: "TripFrance",
            artwork: .init(width: 363.01, height: 351.85, leftInset: -2.98, bottomInset: -7.91)
        ),
        // Additional rewards — same artwork families as the Figma three.
        RewardCardModel(
            id: UUID(),
            title: "Stay in France",
            imageName: "GiftWrap",
            unlockedImageName: "TripFrance",
            artwork: .init(width: 375, height: 281.058, leftInset: -15, bottomInset: -38)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Experiences in France",
            imageName: "Experiences",
            unlockedImageName: "TripFrance",
            artwork: .init(width: 363.04, height: 351.86, leftInset: -2.94, bottomInset: -7.92)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Stay in Italy",
            imageName: "GiftWrap",
            unlockedImageName: "TripItaly",
            artwork: .init(width: 375, height: 281.058, leftInset: -15, bottomInset: -38)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Experiences in Italy",
            imageName: "Experiences",
            unlockedImageName: "TripItaly",
            artwork: .init(width: 363.04, height: 351.86, leftInset: -2.94, bottomInset: -7.92)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Spain Travel Pass",
            imageName: "Schengen",
            unlockedImageName: "TripSpain",
            artwork: .init(width: 363.01, height: 351.85, leftInset: -2.98, bottomInset: -7.91)
        )
    ]
}

/// Rendering description for one of the three visible slots in the stack.
struct StackSlot: Equatable {
    let width: CGFloat
    let height: CGFloat
    let yOffset: CGFloat        // signed offset from screen vertical center
    let opacity: Double
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowSpread: CGFloat   // Figma's shadow spread; SwiftUI has no spread,
                                // so we add it to the shadowRadius below.

    /// All values verbatim from the Figma source.
    static let front = StackSlot(
        width: 326,
        height: 225,
        yOffset: -13.5,
        opacity: 1.0,
        cornerRadius: 20,
        shadowRadius: 52,
        shadowSpread: 40
    )
    static let middle = StackSlot(
        width: 300.364,
        height: 207.307,
        yOffset: 70.5,
        opacity: 0.60,
        cornerRadius: 18.427,
        shadowRadius: 47.911,
        shadowSpread: 36.855
    )
    static let back = StackSlot(
        width: 228.364,
        height: 157.613,
        yOffset: 150.5,
        opacity: 0.32,
        cornerRadius: 14.01,
        shadowRadius: 36.426,
        shadowSpread: 28.02
    )

    /// Linear interpolation between two slot configurations.
    static func interpolate(from a: StackSlot, to b: StackSlot, t: CGFloat) -> StackSlot {
        let tt = max(0, min(1, t))
        return StackSlot(
            width: lerp(a.width, b.width, tt),
            height: lerp(a.height, b.height, tt),
            yOffset: lerp(a.yOffset, b.yOffset, tt),
            opacity: Double(lerp(CGFloat(a.opacity), CGFloat(b.opacity), tt)),
            cornerRadius: lerp(a.cornerRadius, b.cornerRadius, tt),
            shadowRadius: lerp(a.shadowRadius, b.shadowRadius, tt),
            shadowSpread: lerp(a.shadowSpread, b.shadowSpread, tt)
        )
    }
}

@inline(__always)
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

struct RewardCardView: View {
    let model: RewardCardModel
    let slot: StackSlot
    /// When `true` the gift-wrap artwork is replaced by the destination
    /// photograph filling the card header. Driven by the slide-to-unlock
    /// control on the rewards screen; pure passthrough — no scroll or
    /// stack-interaction logic depends on it.
    var isUnlocked: Bool = false

    /// Reference (front-slot) values used to derive proportional positions for
    /// internal elements. These match the Figma "Stay in Germany" card.
    private let referenceWidth: CGFloat = 326
    private let referenceHeight: CGFloat = 225
    private let referenceHeaderHeight: CGFloat = 157
    /// The Figma title sits with its vertical center at y = card.center + 64.5
    /// in the front card. As a ratio of card height, that's (112.5 + 64.5)/225.
    private let referenceTitleCenterY: CGFloat = 177
    private let referenceTitleLeading: CGFloat = 20
    private let referenceTitleSize: CGFloat = 20
    private let referenceTitleLineHeight: CGFloat = 28

    private var scale: CGFloat { slot.width / referenceWidth }

    var body: some View {
        // Render the card at a fixed reference size with fixed font size,
        // then apply a single .scaleEffect for the slot's size. This avoids
        // re-laying out the text and re-rasterizing the font at every
        // fractional size during a drag — that re-rasterization is what was
        // causing the per-frame lag and the "Unable to update Font Descriptor"
        // log spam.
        ZStack(alignment: .topLeading) {
            DesignColors.cardSurface

            DesignColors.cardYellow
                .frame(width: referenceWidth, height: referenceHeaderHeight)

            if isUnlocked {
                // Unlocked state: destination photograph fills the yellow
                // header area (326 × 157). The yellow rect underneath is
                // covered, so the unlocked card reads as a photo card.
                Image(model.unlockedImageName)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: referenceWidth, height: referenceHeaderHeight)
                    .clipped()
            } else {
                // Locked state: gift-wrap artwork at its Figma-defined offset.
                Image(model.imageName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: model.artwork.width, height: model.artwork.height)
                    .offset(
                        x: model.artwork.leftInset,
                        y: referenceHeight - model.artwork.height - model.artwork.bottomInset
                    )
            }

            Text(model.title)
                .font(DesignFont.semibold(referenceTitleSize))
                .foregroundColor(.black)
                .frame(height: referenceTitleLineHeight)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: referenceTitleLeading,
                        y: referenceTitleCenterY - referenceTitleLineHeight / 2)
        }
        .frame(width: referenceWidth, height: referenceHeight, alignment: .topLeading)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: StackSlot.front.cornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(0.04),
            radius: (StackSlot.front.shadowRadius + StackSlot.front.shadowSpread) / 2,
            x: 0,
            y: 0
        )
        .scaleEffect(scale, anchor: .center)
        .opacity(slot.opacity)
    }
}

