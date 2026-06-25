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
    /// Alert/Yellow/600 — "London, England" subtitle.
    static let alertYellow600 = Color(red: 0xAD / 255, green: 0x68 / 255, blue: 0x00 / 255)
    /// Primary/Scapia/400 — "Experience" pill text + icon.
    static let primaryScapia400 = Color(red: 0xF1 / 255, green: 0x4D / 255, blue: 0x00 / 255)
    /// Trip-card vertical gradient stops (top → bottom).
    static let tripCardGradientTop = Color(red: 0xE8 / 255, green: 0x76 / 255, blue: 0x02 / 255)
    static let tripCardGradientBottom = Color(red: 0xFD / 255, green: 0xD9 / 255, blue: 0x10 / 255)
    /// 56% black — "24 Mar" date text on the experience row.
    static let textBlack56 = Color.black.opacity(0.56)
    /// Trip-detail screen background — Figma node 1054:17994.
    static let detailBackground = Color(red: 0xFD / 255, green: 0xFF / 255, blue: 0xFA / 255)
    /// Alert/Yellow/000 — "Your trip name" subtitle on the trip-detail screen.
    static let alertYellow000 = Color(red: 0xFF / 255, green: 0xFB / 255, blue: 0xE6 / 255)
    /// Cream-yellow used for the "Rewards" wordmark on the rewards screen.
    /// Figma colour #FFF2E0.
    static let rewardsTextCream = Color(red: 0xFF / 255, green: 0xF2 / 255, blue: 0xE0 / 255)
    /// Primary/Scapia/000 — "Your flight is successfully booked" text. #FFEAE0.
    static let primaryScapia000 = Color(red: 0xFF / 255, green: 0xEA / 255, blue: 0xE0 / 255)
    /// Alert/Yellow/500 — checkmark amber on the flight booked screen. #D48806.
    static let alertYellow500 = Color(red: 0xD4 / 255, green: 0x88 / 255, blue: 0x06 / 255)
    /// Rewards gradient top (screens 2 & 3) — starts at 15%. #E96307.
    static let rewardsGradientTop = Color(red: 0xE9 / 255, green: 0x63 / 255, blue: 0x07 / 255)
    /// Alert/Yellow/700 — "You just earned" label on the trip page. #874D00.
    static let alertYellow700 = Color(red: 0x87 / 255, green: 0x4D / 255, blue: 0x00 / 255)
    /// Page background gradient shown once the rewards sheet rises — Figma
    /// node 2615:1910. Top #F7F9F4 (≈ today's bg) → bottom #FBE8C2 (warm cream).
    static let sheetBgTop = Color(red: 0xF7 / 255, green: 0xF9 / 255, blue: 0xF4 / 255)
    static let sheetBgBottom = Color(red: 0xFB / 255, green: 0xE8 / 255, blue: 0xC2 / 255)
}

enum DesignFont {
    // Lexend Deca ships as a single variable font (LexendDeca-VF.ttf) with
    // named instances at each weight. SwiftUI's `Font.custom(...).weight(...)`
    // modifier silently fails to push the wght axis on the registered VF, so
    // we address each weight by its PostScript instance name directly.
    static func regular(_ size: CGFloat) -> Font {
        Font.custom("LexendDeca-Regular", size: size)
    }

    static func medium(_ size: CGFloat) -> Font {
        Font.custom("LexendDeca-Medium", size: size)
    }

    static func semibold(_ size: CGFloat) -> Font {
        Font.custom("LexendDeca-SemiBold", size: size)
    }

    static func bold(_ size: CGFloat) -> Font {
        Font.custom("LexendDeca-Bold", size: size)
    }

    static func extraBold(_ size: CGFloat) -> Font {
        Font.custom("LexendDeca-ExtraBold", size: size)
    }

    static func black(_ size: CGFloat) -> Font {
        Font.custom("LexendDeca-Black", size: size)
    }
}
