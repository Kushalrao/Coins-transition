//
//  RiveGiftView.swift
//  Vacations
//
//  SwiftUI wrapper around the bundled Rive gift animation
//  (GiftAnimation.riv). Uses the Rive iOS runtime (added via SPM:
//  https://github.com/rive-app/rive-ios, product "RiveRuntime").
//

import SwiftUI
import RiveRuntime

/// Plays the bundled `GiftAnimation.riv`. `RiveViewModel` autoplays the
/// default animation/state machine; `.contain` keeps the artboard's aspect
/// ratio inside whatever frame the caller gives it.
struct RiveGiftView: View {
    @StateObject private var gift = RiveViewModel(fileName: "GiftAnimation", fit: .contain)

    var body: some View {
        gift.view()
    }
}
