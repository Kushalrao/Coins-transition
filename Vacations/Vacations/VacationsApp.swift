//
//  VacationsApp.swift
//  Vacations
//
//  Created by Kushal Yadav on 05/05/26.
//

import SwiftUI
import CoreText

@main
struct VacationsApp: App {
    init() {
        FontLoader.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            BookingFlowView()
        }
    }
}

/// Top-level flow shown after a successful booking.
///
/// The rewards-communication sequence (flight confirmation + the two coins
/// screens in `RewardsEarnedView`) has been removed; the flow now starts
/// directly on `TripAnnouncementView`, whose own warp-in entrance plays on
/// appear, unchanged.
struct BookingFlowView: View {
    var body: some View {
        // Two maintained versions of the flow. V2 is the one we're iterating
        // on; swap to `TripAnnouncementView()` to show the original V1.
        TripAnnouncementViewV2()
    }
}

enum FontLoader {
    static func registerFonts() {
        let names = ["LexendDeca-VF"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
