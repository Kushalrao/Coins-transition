//
//  DesignTokens.swift
//  Vacations
//
//  Exact tokens lifted from the Figma source (file TYBKT7Qs2E6zdT6h2BuFWZ, node 1876:5990).
//

import SwiftUI

enum DesignColors {
    static let background = Color(red: 0xF9 / 255, green: 0xFB / 255, blue: 0xF6 / 255)
    static let textHighEmphasis = Color(red: 0x26 / 255, green: 0x2B / 255, blue: 0x30 / 255)
    static let cardYellow = Color(red: 0xFC / 255, green: 0xD8 / 255, blue: 0x00 / 255)
    static let cardSurface = Color.white
    static let closeBackground = Color(red: 0x26 / 255, green: 0x2B / 255, blue: 0x30 / 255).opacity(0.62)
    static let closeBorder = Color(red: 0x26 / 255, green: 0x2B / 255, blue: 0x30 / 255)
}

enum DesignFont {
    private static let family = "LexendDeca"

    static func regular(_ size: CGFloat) -> Font {
        Font.custom(family, size: size).weight(.regular)
    }

    static func semibold(_ size: CGFloat) -> Font {
        Font.custom(family, size: size).weight(.semibold)
    }
}
