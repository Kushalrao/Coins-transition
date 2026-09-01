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
                .preferredColorScheme(.light)
        }
    }
}

/// The coins-credit cinematic, extracted from the "My trips" prototype so the
/// sequence can be run and re-timed on its own.
///
/// The app opens straight onto it and it plays once on appear. Nothing here
/// navigates: in the full prototype the card's "View booking details" and
/// offers pill push to the trip page, and both are left as no-ops.
///
/// Two variants of the sequence are maintained, both always built — see
/// `CoinsVariant`. A plain Run gives `refined` (particle dissolve + aurora);
/// reach the other with:
///
///     xcrun simctl launch <udid> kushal.Vacations -coinsVariant classic
///
/// The confirmation celebrates a flight by default; `-bookingKind train`
/// (or stay/experience/bus) exercises the other artwork.
struct BookingFlowView: View {
    var body: some View {
        TripAnnouncementViewV2()
    }
}

enum FontLoader {
    /// Lexend Deca ships here as a variable font; `DesignFont` addresses its
    /// named instances (e.g. "LexendDeca-Black") directly, which requires
    /// registering the VF with CoreText (UIAppFonts won't expose them).
    static func registerFonts() {
        let names = ["LexendDeca-VF"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
