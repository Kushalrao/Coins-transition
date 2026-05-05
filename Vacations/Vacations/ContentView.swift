//
//  ContentView.swift
//  Vacations
//
//  Created by Kushal Yadav on 05/05/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            DesignColors.background
                .ignoresSafeArea()

            // Decorative stars — values lifted from the Figma frame.
            // Top-left cluster
            Image("Star4")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .position(x: 48 + 14, y: 124 + 14)

            Image("Star5")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .position(x: 30 + 6, y: 121 + 6)

            Image("Star3")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .position(x: 22 + 11.5, y: 160 + 11.5)

            // Mid-right cluster
            Image("Star4")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .position(x: 334 + 14, y: 595 + 14)

            Image("Star3")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .position(x: 307 + 11.5, y: 635 + 11.5)

            // The reward stack itself, centered on the screen.
            RewardStackView()
                .ignoresSafeArea()

            // Close button — top-right pill, 40 × 40, radius 100, ~62% dark fill
            CloseButton()
                .position(x: 316.76 + 20, y: 67.94 + 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignColors.background)
    }
}

private struct CloseButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(DesignColors.closeBackground)
            Circle()
                .stroke(DesignColors.closeBorder, lineWidth: 1)

            // 24×24 icon area; SF Symbol "xmark" approximates the Figma vector.
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
        }
        .frame(width: 40, height: 40)
    }
}

#Preview {
    ContentView()
}
