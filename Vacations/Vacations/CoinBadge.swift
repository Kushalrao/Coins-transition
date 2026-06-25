//
//  CoinBadge.swift
//  Vacations
//
//  Hand-built 3D travel-coin badge used on the Rewards Earned screen.
//  Composed entirely of SwiftUI shapes + gradients — no bitmap assets.
//  Same structure as the original Figma reference (gold rim with directional
//  shading, two-tone inner face, scattered sparkles, white suitcase glyph,
//  glossy top-left highlight) but rendered in yellow/amber tones rather
//  than blue. The whole disc gently wobbles around the vertical axis to
//  read as a 3D object catching light.
//

import SwiftUI

struct CoinBadge: View {
    var size: CGFloat = 144

    @State private var rotationY: Double = -12

    // MARK: - Yellow palette

    /// Top-edge highlight on the gold rim.
    private let rimHighlight = Color(red: 1.00, green: 0.93, blue: 0.55)
    /// Gold midtone — most of the rim sits in this colour.
    private let rimGold      = Color(red: 0.94, green: 0.70, blue: 0.10)
    /// Shadow on the bottom-right rim, gives the rim its 3D edge.
    private let rimShadow    = Color(red: 0.42, green: 0.25, blue: 0.00)

    /// Upper-half warm yellow, top-of-face.
    private let faceTop      = Color(red: 1.00, green: 0.83, blue: 0.30)
    /// Upper-half warm yellow, just above the dark band.
    private let faceBottom   = Color(red: 0.95, green: 0.62, blue: 0.05)

    /// Lower band — the dark "ground" the suitcase sits on. Top stop.
    private let groundTop    = Color(red: 0.42, green: 0.20, blue: 0.00)
    /// Lower band — bottom stop, very dark amber.
    private let groundBottom = Color(red: 0.16, green: 0.07, blue: 0.00)

    var body: some View {
        ZStack {
            // Soft drop-shadow under the coin so it floats on the orange bg.
            Circle()
                .fill(Color.black.opacity(0.32))
                .frame(width: size * 0.96, height: size * 0.96)
                .offset(y: size * 0.06)
                .blur(radius: size * 0.07)

            // Gold rim — angular gradient gives the directional 3D shading
            // with the brightest light at the top-left and the deepest
            // shadow at the bottom-right.
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: rimHighlight, location: 0.00),
                            .init(color: rimGold,      location: 0.18),
                            .init(color: rimShadow,    location: 0.50),
                            .init(color: rimGold,      location: 0.82),
                            .init(color: rimHighlight, location: 1.00)
                        ]),
                        center: .center,
                        startAngle: .degrees(-95),
                        endAngle: .degrees(265)
                    )
                )
                .overlay(
                    // Inner thin highlight ring just inside the rim, sells
                    // the polished bevel.
                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: size * 0.012)
                        .padding(size * 0.085)
                )

            // Inner face — clipped to a circle inside the rim.
            innerFace
                .frame(width: size, height: size)
                .clipShape(Circle().inset(by: size * 0.10))

            // Top-left glossy highlight on the dome — light bouncing off
            // the top of the coin.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), Color.clear],
                        center: UnitPoint(x: 0.30, y: 0.22),
                        startRadius: 1,
                        endRadius: size * 0.28
                    )
                )
                .frame(width: size * 0.78, height: size * 0.78)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .rotation3DEffect(
            .degrees(rotationY),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.45
        )
        .onAppear {
            // Gentle wobble keeps the back of the coin out of view (full
            // 360° rotation would show the mirrored "back" which we don't
            // model). Reads as a 3D object catching light.
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                rotationY = 12
            }
        }
    }

    // MARK: - Inner face (yellow upper, dark amber band, sparkles, suitcase)

    private var innerFace: some View {
        ZStack {
            // Warm yellow upper background.
            LinearGradient(
                colors: [faceTop, faceBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Dark amber "ground" anchored to the bottom.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [groundTop, groundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: size * 0.27)
            }

            // Sparkle stars in the upper area, mirroring the original
            // composition (one upper-left smaller, one mid-right larger,
            // one lower-left tiny).
            sparkles

            // Suitcase glyph — white, centred horizontally, sitting just
            // above the ground band.
            Image(systemName: "suitcase.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
                .frame(width: size * 0.27)
                .offset(y: -size * 0.02)
        }
    }

    private var sparkles: some View {
        Group {
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.07))
                .foregroundColor(.white)
                .offset(x: -size * 0.22, y: -size * 0.14)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.10))
                .foregroundColor(.white)
                .offset(x: size * 0.22, y: size * 0.04)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.05))
                .foregroundColor(.white)
                .offset(x: -size * 0.18, y: size * 0.10)
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.95, green: 0.55, blue: 0.0)
            .ignoresSafeArea()
        CoinBadge()
    }
}
