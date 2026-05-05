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
            title: "Stay in Germany",
            imageName: "GiftWrap",
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
            title: "Experiences in Germany",
            imageName: "Experiences",
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
            artwork: .init(width: 363.01, height: 351.85, leftInset: -2.98, bottomInset: -7.91)
        ),
        // Additional rewards — same artwork families as the Figma three.
        RewardCardModel(
            id: UUID(),
            title: "Stay in France",
            imageName: "GiftWrap",
            artwork: .init(width: 375, height: 281.058, leftInset: -15, bottomInset: -38)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Experiences in France",
            imageName: "Experiences",
            artwork: .init(width: 363.04, height: 351.86, leftInset: -2.94, bottomInset: -7.92)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Stay in Italy",
            imageName: "GiftWrap",
            artwork: .init(width: 375, height: 281.058, leftInset: -15, bottomInset: -38)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Experiences in Italy",
            imageName: "Experiences",
            artwork: .init(width: 363.04, height: 351.86, leftInset: -2.94, bottomInset: -7.92)
        ),
        RewardCardModel(
            id: UUID(),
            title: "Spain Travel Pass",
            imageName: "Schengen",
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
        let w = slot.width
        let h = slot.height
        let headerH = referenceHeaderHeight * scale
        let titleY = referenceTitleCenterY * scale
        let titleX = referenceTitleLeading * scale
        let titleSize = referenceTitleSize * scale
        let titleLine = referenceTitleLineHeight * scale

        ZStack(alignment: .topLeading) {
            // White card surface (the visible footer area)
            DesignColors.cardSurface

            // Yellow header — full-width, top of card, square bottom
            DesignColors.cardYellow
                .frame(width: w, height: headerH)

            // Gift-wrap artwork. Sized + positioned in front-slot coordinates
            // then scaled. Using `.offset` after a fixed frame keeps the
            // artwork's geometry stable regardless of slot.
            Image(model.imageName)
                .resizable()
                .interpolation(.high)
                .frame(width: model.artwork.width * scale, height: model.artwork.height * scale)
                .offset(
                    x: model.artwork.leftInset * scale,
                    y: h - (model.artwork.height * scale) - (model.artwork.bottomInset * scale)
                )

            // Title — Lexend Deca SemiBold, vertically centered at titleY
            Text(model.title)
                .font(DesignFont.semibold(titleSize))
                .foregroundColor(.black)
                .frame(height: titleLine)
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: titleX, y: titleY - titleLine / 2)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: slot.cornerRadius, style: .continuous))
        // Approximate Figma's spread by inflating the SwiftUI shadow radius.
        // Figma: 0px 0px {radius}px {spread}px rgba(0,0,0,0.04)
        .shadow(
            color: .black.opacity(0.04),
            radius: (slot.shadowRadius + slot.shadowSpread) / 2,
            x: 0,
            y: 0
        )
        .opacity(slot.opacity)
    }
}

