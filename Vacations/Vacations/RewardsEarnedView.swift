//
//  RewardsEarnedView.swift
//  Vacations
//
//  Three-screen rewards sequence shown after a successful flight booking.
//  Figma file TYBKT7Qs2E6zdT6h2BuFWZ nodes 2399:1013, 2399:1234, 2399:1315.
//
//  Sequence:
//    1. FlightBookedView  — gradient + checkmark + "Your flight is successfully booked"
//    2. CoinsEarnedView   — balance pill + staggered coin count + "Coins earned…"
//    3. CoinsToBalanceView — coins stream from earned number up into the balance pill
//  After screen 3 auto-completes, `onComplete` fires.
//

import SwiftUI

// MARK: - Container

struct RewardsEarnedView: View {
    var coinsEarned: Int = 32_800
    var existingBalance: Int = 5_790
    var onComplete: (() -> Void)? = nil

    @State private var phase: RewardsPhase = .flightBooked

    enum RewardsPhase { case flightBooked, coinsEarned, coinsToBalance }

    var body: some View {
        ZStack {
            switch phase {
            case .flightBooked:
                FlightBookedView {
                    withAnimation(.easeInOut(duration: 0.55)) { phase = .coinsEarned }
                }
                .transition(.opacity)
            case .coinsEarned:
                CoinsEarnedView(coinsEarned: coinsEarned, existingBalance: existingBalance) {
                    withAnimation(.easeInOut(duration: 0.55)) { phase = .coinsToBalance }
                }
                .transition(.opacity)
            case .coinsToBalance:
                CoinsToBalanceView(coinsEarned: coinsEarned, existingBalance: existingBalance) {
                    onComplete?()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.55), value: phase)
    }
}

// MARK: - Shared gradient background

private struct RewardsBackground: View {
    var topColor: Color = DesignColors.tripCardGradientTop
    var topLocation: CGFloat = 0

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: topColor, location: topLocation),
                .init(color: DesignColors.tripCardGradientBottom, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Balance pill (shared by screens 2 & 3)

private struct BalancePill: View {
    let balance: String
    /// Screen 2: compact — coin + balance number + "Coins balance" label.
    /// Screen 3: large  — coin + balance number in ExtraBold 24, no label.
    var showLabel: Bool = true

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.15))

            HStack(spacing: 8) {
                Image("SpinCoinBadge")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)

                if showLabel {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(balance)
                            .font(DesignFont.bold(16))
                            .foregroundColor(Color(red: 20/255, green: 28/255, blue: 32/255))
                            .tracking(0.64)
                            .lineLimit(1)
                        Text("Coins balance")
                            .font(DesignFont.regular(12))
                            .foregroundColor(Color.black.opacity(0.8))
                            .lineLimit(1)
                    }
                } else {
                    Text(balance)
                        .font(DesignFont.extraBold(24))
                        .foregroundColor(Color(red: 20/255, green: 28/255, blue: 32/255))
                        .tracking(0.96)
                        .lineLimit(1)
                }
            }
            .padding(.leading, showLabel ? 12 : 16)
            .padding(.trailing, 12)
            .frame(height: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule().fill(Color.white))
            .padding(4)
        }
        .frame(minWidth: 160, minHeight: 60, maxHeight: 60)
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(Capsule())
        .shadow(color: Color.white.opacity(0.64), radius: 22, x: 0, y: 0)
    }
}

// MARK: - Screen 1: Flight Booked (node 2399:1013)

private struct FlightBookedView: View {
    var onComplete: () -> Void

    @State private var iconVisible = false
    @State private var textVisible = false

    var body: some View {
        GeometryReader { proxy in
            let cx = proxy.size.width / 2
            // 20 pt below the safe-area top edge, regardless of device notch/island height.
            let iconCenterY = proxy.safeAreaInsets.top + 20 + 53   // 53 = half of 106

            ZStack(alignment: .topLeading) {
                RewardsBackground()

                // Cream rounded-square, 106×106, cornerRadius 40 — node 2399:1138
                ZStack {
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(DesignColors.alertYellow000)
                        .shadow(color: Color.white.opacity(0.2), radius: 57, x: 0, y: 4)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(DesignColors.alertYellow500)
                }
                .frame(width: 106, height: 106)
                .opacity(iconVisible ? 1 : 0)
                .scaleEffect(iconVisible ? 1 : 0.72)
                .position(x: cx, y: iconCenterY)

                // "Your flight is successfully booked" — Figma centre y ≈ 460
                Text("Your flight is\nsuccessfully booked")
                    .font(DesignFont.semibold(28))
                    .foregroundColor(DesignColors.primaryScapia000)
                    .multilineTextAlignment(.center)
                    .lineSpacing(36 - 28 * 1.2)
                    .frame(width: 310, alignment: .top)
                    .opacity(textVisible ? 1 : 0)
                    .position(x: cx, y: 460)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { iconVisible = true }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.easeOut(duration: 0.45)) { textVisible = true }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            onComplete()
        }
    }
}

// MARK: - Screen 2: Coins Earned (node 2399:1234)

private struct CoinsEarnedView: View {
    var coinsEarned: Int
    var existingBalance: Int
    var onComplete: () -> Void

    @State private var pillVisible = false
    @State private var revealedCount = 0
    @State private var subtitleVisible = false
    @State private var footerVisible = false

    private var digitChars: [String] {
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        let s = fmt.string(from: NSNumber(value: coinsEarned)) ?? "\(coinsEarned)"
        return s.map(String.init)
    }

    private var balanceText: String {
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: existingBalance)) ?? "\(existingBalance)"
    }

    // token 0 = coin icon; tokens 1…n = digit chars
    private var totalTokens: Int { 1 + digitChars.count }

    var body: some View {
        GeometryReader { proxy in
            let cx = proxy.size.width / 2
            // 20 pt below safe-area top — keeps pill just below the notch/island on all devices
            let pillCenterY = proxy.safeAreaInsets.top + 20 + 30   // 30 = half of 60

            ZStack(alignment: .topLeading) {
                RewardsBackground(topColor: DesignColors.rewardsGradientTop, topLocation: 0.15)

                // Balance pill
                BalancePill(balance: balanceText, showLabel: true)
                    .opacity(pillVisible ? 1 : 0)
                    .scaleEffect(pillVisible ? 1 : 0.82)
                    .position(x: cx, y: pillCenterY)

                // Coin icon + staggered digits — Figma centre y = 375
                HStack(spacing: 8) {
                    Image("SpinCoinBadge")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 40, height: 40)
                        .opacity(revealedCount > 0 ? 1 : 0)
                        .scaleEffect(revealedCount > 0 ? 1 : 0.65)

                    HStack(spacing: 0) {
                        ForEach(Array(digitChars.enumerated()), id: \.offset) { i, ch in
                            Text(ch)
                                .font(DesignFont.extraBold(44))
                                .foregroundColor(Color.white.opacity(0.88))
                                .opacity(revealedCount > i + 1 ? 1 : 0)
                                .scaleEffect(revealedCount > i + 1 ? 1 : 0.65)
                        }
                    }
                }
                .position(x: cx, y: 375)

                // Subtitle
                Text("Coins earned on your\nflight booking")
                    .font(DesignFont.semibold(28))
                    .foregroundColor(DesignColors.alertYellow000)
                    .multilineTextAlignment(.center)
                    .lineSpacing(36 - 28 * 1.2)
                    .frame(width: 310, alignment: .top)
                    .opacity(subtitleVisible ? 1 : 0)
                    .position(x: cx, y: 460)

                rewardsLockup
                    .opacity(footerVisible ? 1 : 0)
                    .position(x: cx, y: 738)

                Text("Terms and conditions apply")
                    .font(DesignFont.semibold(14))
                    .foregroundColor(DesignColors.alertYellow000)
                    .multilineTextAlignment(.center)
                    .frame(width: 310)
                    .opacity(footerVisible ? 1 : 0)
                    .position(x: cx, y: 776)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await runSequence() }
    }

    private func runSequence() async {
        try? await Task.sleep(nanoseconds: 150_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { pillVisible = true }

        try? await Task.sleep(nanoseconds: 300_000_000)
        for _ in 0..<totalTokens {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { revealedCount += 1 }
            try? await Task.sleep(nanoseconds: 130_000_000)
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        withAnimation(.easeOut(duration: 0.45)) { subtitleVisible = true }
        try? await Task.sleep(nanoseconds: 350_000_000)
        withAnimation(.easeOut(duration: 0.45)) { footerVisible = true }

        try? await Task.sleep(nanoseconds: 1_800_000_000)
        onComplete()
    }

    private var rewardsLockup: some View {
        VStack(spacing: 0) {
            Image("ScapiaLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 63.059, height: 16)
            Text("Rewards")
                .font(.system(size: 21.333, weight: .semibold, design: .serif))
                .foregroundColor(DesignColors.rewardsTextCream)
                .tracking(-0.512)
                .shadow(color: Color.white.opacity(0.25), radius: 2.667, x: 0, y: 2.667)
        }
        .frame(width: 85, height: 40)
    }
}

// MARK: - Screen 3: Coins to Balance (node 2399:1315)

private struct CoinsToBalanceView: View {
    var coinsEarned: Int
    var existingBalance: Int
    var onComplete: () -> Void

    // Each coin has an independent opacity and "at-pill" position flag so the
    // two-step animation (pop-in at number → fly to pill + fade) works correctly.
    @State private var coinOpacity: [Double] = Array(repeating: 0, count: 5)
    @State private var coinAtPill: [Bool]   = Array(repeating: false, count: 5)
    @State private var pillScale: CGFloat = 1
    @State private var balanceUpdated = false
    @State private var numberVisible = false
    @State private var subtitleVisible = false
    @State private var footerVisible = false

    // Horizontal/vertical spread for each coin particle, relative to the
    // earned-number display centre. Sizes match the Figma coin variants.
    private let coinSpread: [(dx: CGFloat, dy: CGFloat, size: CGFloat)] = [
        (-44,   8, 28),
        (-22,  -6, 24),
        (  0,   4, 32),
        ( 22,  -8, 24),
        ( 44,   6, 28),
    ]

    // Vertical centre of the number row — matches .position(y: 375) in body
    private let numberCenterY: CGFloat = 375

    private var newBalance: Int { existingBalance + coinsEarned }

    private var earnedText: String {
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: coinsEarned)) ?? "\(coinsEarned)"
    }

    private var balanceText: String {
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        let val = balanceUpdated ? newBalance : existingBalance
        return fmt.string(from: NSNumber(value: val)) ?? "\(val)"
    }

    var body: some View {
        GeometryReader { proxy in
            let cx = proxy.size.width / 2
            // 20 pt below the safe-area top edge — same rule as the pill on screen 2
            let pillCenterY = proxy.safeAreaInsets.top + 20 + 30

            ZStack(alignment: .topLeading) {
                RewardsBackground(topColor: DesignColors.rewardsGradientTop, topLocation: 0.15)

                // Coin particles — start spread around the earned-number,
                // fly upward into the balance pill when launched.
                ForEach(0..<coinSpread.count, id: \.self) { i in
                    let sp = coinSpread[i]
                    Image("SpinCoinBadge")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: sp.size, height: sp.size)
                        .opacity(coinOpacity[i])
                        .position(
                            x: coinAtPill[i] ? cx            : cx + sp.dx,
                            y: coinAtPill[i] ? pillCenterY   : numberCenterY + sp.dy
                        )
                }

                // Balance pill — 20 pt below safe-area top
                BalancePill(balance: balanceText, showLabel: false)
                    .scaleEffect(pillScale)
                    .position(x: cx, y: pillCenterY)

                // Earned coin icon + number
                HStack(spacing: 8) {
                    Image("SpinCoinBadge")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 40, height: 40)
                    Text(earnedText)
                        .font(DesignFont.extraBold(44))
                        .foregroundColor(Color.white.opacity(0.88))
                }
                .opacity(numberVisible ? 1 : 0)
                .scaleEffect(numberVisible ? 1 : 0.85)
                .position(x: cx, y: numberCenterY)

                // Subtitle
                Text("Use coins for your\nnext travel booking")
                    .font(DesignFont.semibold(28))
                    .foregroundColor(DesignColors.alertYellow000)
                    .multilineTextAlignment(.center)
                    .lineSpacing(36 - 28 * 1.2)
                    .frame(width: 310, alignment: .top)
                    .opacity(subtitleVisible ? 1 : 0)
                    .position(x: cx, y: 460)

                rewardsLockup
                    .opacity(footerVisible ? 1 : 0)
                    .position(x: cx, y: 738)

                Text("Terms and conditions apply")
                    .font(DesignFont.semibold(14))
                    .foregroundColor(DesignColors.alertYellow000)
                    .multilineTextAlignment(.center)
                    .frame(width: 310)
                    .opacity(footerVisible ? 1 : 0)
                    .position(x: cx, y: 776)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await runSequence() }
    }

    private func runSequence() async {
        // Number and subtitle fade in first
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeOut(duration: 0.45)) {
            numberVisible  = true
            subtitleVisible = true
        }

        // After a beat, stream coins one-by-one from the number up to the pill.
        // Each coin pops into existence at its spread position, then immediately
        // flies up to the pill centre while fading to zero — reads as coins being
        // "sent" from the earned total into the balance.
        try? await Task.sleep(nanoseconds: 600_000_000)
        for i in 0..<coinSpread.count {
            try? await Task.sleep(nanoseconds: 90_000_000)

            // Step 1: pop coin in at start position
            withAnimation(.spring(response: 0.18, dampingFraction: 0.65)) {
                coinOpacity[i] = 1
            }

            // Step 2: 60 ms later, fly to pill and fade out
            let idx = i
            Task {
                try? await Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.easeIn(duration: 0.52)) {
                    coinAtPill[idx]   = true
                    coinOpacity[idx]  = 0
                }
            }
        }

        // Pill pulses and balance updates when the last coin arrives
        let lastCoinArrival: UInt64 = UInt64(coinSpread.count) * 90_000_000 + 60_000_000 + 520_000_000
        try? await Task.sleep(nanoseconds: lastCoinArrival + 80_000_000)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
            pillScale       = 1.18
            balanceUpdated  = true
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            pillScale = 1
        }

        try? await Task.sleep(nanoseconds: 350_000_000)
        withAnimation(.easeOut(duration: 0.45)) { footerVisible = true }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        onComplete()
    }

    private var rewardsLockup: some View {
        VStack(spacing: 0) {
            Image("ScapiaLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 63.059, height: 16)
            Text("Rewards")
                .font(.system(size: 21.333, weight: .semibold, design: .serif))
                .foregroundColor(DesignColors.rewardsTextCream)
                .tracking(-0.512)
                .shadow(color: Color.white.opacity(0.25), radius: 2.667, x: 0, y: 2.667)
        }
        .frame(width: 85, height: 40)
    }
}

#Preview {
    RewardsEarnedView()
}
