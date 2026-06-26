//
//  TripAnnouncementViewV2.swift
//  Vacations
//
//  V2 of the post-booking flow. A three-phase sequence:
//    1. "Travel rewards earned"  (Figma node 3044:1733) — orange screen that
//       counts the earned rewards up.
//    2. "Added to balance"       (Figma node 3044:1662) — coins fly up from
//       the earned number and are deposited into a balance pill that counts up.
//    3. The flight-booked trip card (Figma node 3183:10291) — crossfades in
//       and plays its warp-in entrance.
//

import SwiftUI
import UIKit
import Combine

struct TripAnnouncementViewV2: View {

    private enum RewardPhase { case earned, added, trip }

    // Sequence state
    @State private var phase: RewardPhase = .earned
    @State private var appeared = false        // first fade/scale-in of the earned screen
    @State private var rollEarned = false      // triggers the earned ticker roll-in
    @State private var numberShown = true      // earned number visible until it dissolves
    @State private var balanceCount = 0        // top balance pill (counts to 5,790)
    @State private var pillShown = false        // balance pill springs in as particles rise
    @State private var headingReveal: CGFloat = 0 // "Instantly added" left-to-right wipe
    @State private var shineActive = false      // border shine runs once particles settle
    @State private var shineAngle: Double = 0
    @State private var pillPulse: CGFloat = 1    // gentle scale pulse during the shine
    // Apple-Wallet-style particle disintegration of the number.
    @State private var dissolveDots: [DissolveDot] = []
    @State private var dissolveStart: Date? = nil   // moment the disintegration began
    @State private var dissolveProgress: CGFloat = 0 // mask sweep 0→1 (bottom→top)
    @State private var bandTop: CGFloat = -40        // glyph-pixel band (rel. to centre)
    @State private var bandBottom: CGFloat = 40
    // Subtle anticipation lift on the solid number, just before it dissolves
    // (purely cosmetic — particles are unaffected). Flip `textLiftEnabled` off
    // to fully revert this behaviour.
    private let textLiftEnabled = true
    @State private var numberZoom: CGFloat = 1
    @State private var numberLift: CGFloat = 0

    // The dissolve sweep: a short crossfade beat, then the wave climbs the text.
    private let dissolveWaveStart: Double = 0.18
    private let dissolveWaveSpread: Double = 0.95

    // Trip-card reveal state
    @State private var entranceTrigger = 0
    @State private var headingShown = false
    @State private var bodyShown = false
    // Offer countdown (24:32:27)
    @State private var secondsLeft = 24 * 3600 + 32 * 60 + 27

    private let cardW: CGFloat = 326
    private let cardH: CGFloat = 401

    // MARK: Colors (Figma node 3183:10291)
    private let bgTop = Color(red: 1.0, green: 0xF8 / 255, blue: 0xEE / 255)        // #FFF8EE
    private let bgBottom = Color(red: 0xF7 / 255, green: 0xF9 / 255, blue: 0xF4 / 255) // #F7F9F4
    private let detailBG = Color(red: 0xF8 / 255, green: 0xFA / 255, blue: 0xF5 / 255) // #F8FAF5
    private let imageBG = Color(red: 0xFE / 255, green: 0xF8 / 255, blue: 0xE9 / 255)  // #FEF8E9
    private let navy = Color(red: 0x03 / 255, green: 0x12 / 255, blue: 0x23 / 255)     // #031223
    private let green = Color(red: 0x38 / 255, green: 0x9E / 255, blue: 0x0D / 255)    // #389E0D
    private let offerBG = Color(red: 0xF9 / 255, green: 0xF7 / 255, blue: 0xD1 / 255)  // #F9F7D1
    private let closeBG = Color(red: 0xE9 / 255, green: 0xEB / 255, blue: 0xE7 / 255)  // #E9EBE7
    private let balanceInk = Color(red: 0x14 / 255, green: 0x1C / 255, blue: 0x20 / 255) // #141C20
    // Trip-card background gradient (Figma 3223:2067) — mint → yellow, 50% alpha.
    private let cardMint = Color(red: 0xBD / 255, green: 0xE3 / 255, blue: 0xDF / 255)   // #BDE3DF
    private let alertAmber = Color(red: 0xD4 / 255, green: 0x88 / 255, blue: 0x06 / 255)  // #D48806
    // Coins-communication background (Figma 3377:8172) — orange → yellow.
    private let rewardsBgTop = Color(red: 0xEF / 255, green: 0x60 / 255, blue: 0x04 / 255)  // #EF6004
    private let rewardsTextWhite = Color.white.opacity(0.88)
    private let rewardsLabel = Color(red: 0xFF / 255, green: 0xFB / 255, blue: 0xE6 / 255)  // #FFFBE6

    /// Samples the rendered "32,800" glyphs (using the same per-digit cell
    /// layout the number is drawn with) into a fine particle cloud, so the
    /// number itself disintegrates — Apple-Wallet style — rather than a generic
    /// block. Each particle gets a stagger/duration so it streams up to the pill.
    private func makeDissolveDots() -> [DissolveDot] {
        let chars = Array("32,800")
        let digitW: CGFloat = 41, commaW: CGFloat = 20, fontSize: CGFloat = 64
        let widths = chars.map { $0 == "," ? commaW : digitW }
        let total = widths.reduce(0, +)

        // Pass 1 — collect every glyph-pixel origin (centred on the number).
        var origins: [CGPoint] = []
        var x = -total / 2
        for (i, ch) in chars.enumerated() {
            let cw = widths[i]
            let cx = x + cw / 2
            let pts = GlyphSampler.points(text: String(ch),
                                          fontName: "LexendDeca-Black",
                                          fontSize: fontSize,
                                          maxCount: ch == "," ? 180 : 1020)
            for p in pts { origins.append(CGPoint(x: cx + p.x, y: p.y)) }
            x += cw
        }
        guard !origins.isEmpty else { return [] }

        // Pass 2 — turn each origin into a particle whose lift-off delay is
        // driven by its vertical position, so the text converts to particles as
        // a wave climbing from the BOTTOM of the glyphs to the top, row by row.
        // Each particle's settle point sits on a halo ellipse hugging the pill,
        // so after rising they close up and gather around it.
        let ys = origins.map(\.y)
        let minY = ys.min()!, maxY = ys.max()!
        let span = max(1, maxY - minY)
        bandTop = minY
        bandBottom = maxY
        // 3 particles per sampled glyph pixel → ~3× denser rise. The settle
        // probability is cut to ~1/3 to keep the on-top halo count the same.
        return origins.flatMap { o -> [DissolveDot] in
            (0..<3).compactMap { _ -> DissolveDot? in
                if Double.random(in: 0...1) < 0.2 { return nil }   // drop 20% of total
                let jx = CGFloat.random(in: -2.5...2.5)
                let jy = CGFloat.random(in: -2.5...2.5)
                let frac = Double((maxY - o.y) / span)   // 0 = bottom, 1 = top
                let ang = Double.random(in: 0 ..< (2 * .pi))
                let rr = CGFloat.random(in: 0...14)      // tight band hugging the pill
                let a: CGFloat = 82, b: CGFloat = 32     // halo radii ≈ pill border
                return DissolveDot(
                    origin: CGPoint(x: o.x + jx, y: o.y + jy),
                    orbitAngle: ang,
                    orbitA: a + rr,
                    orbitB: b + rr,
                    orbitSpeed: Double.random(in: 0.1...0.22),   // very slow drift around the pill
                    settles: Double.random(in: 0...1) < 0.034,   // ~1/3 of before stay as the halo
                    // Bow outward mid-flight so the cloud fans out as it rises,
                    // then converges back to the settle point at the top.
                    arc: (o.x >= 0 ? 1 : -1) * CGFloat.random(in: 30...85)
                        + CGFloat.random(in: -10...10),
                    size: .random(in: 2.0...4.0),
                    gold: Double.random(in: 0...1) < 0.7,  // 70% gold, 30% white
                    // birth time tracks the sweep line as it reaches this row
                    delay: dissolveWaveStart + frac * dissolveWaveSpread + .random(in: 0...0.04),
                    dur: .random(in: 0.95...1.5),
                    jamp: .random(in: 1.5...4.5),        // settle "riddle" jitter
                    jfreq: .random(in: 1.4...2.8),
                    jphase: .random(in: 0 ..< (2 * .pi)),
                    twFreq: .random(in: 2.0...4.0),       // twinkle
                    twPhase: .random(in: 0 ..< (2 * .pi))
                )
            }
        }
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            rewardsScreen
                .opacity(phase == .trip ? 0 : 1)

            tripScreen
                .opacity(phase == .trip ? 1 : 0)
        }
        .task { await runSequence() }
        .onReceive(timer) { _ in
            if secondsLeft > 0 { secondsLeft -= 1 }
        }
    }

    // MARK: - Sequence orchestration

    private func runSequence() async {
        // Phase 1 — Travel rewards earned. The amount simply appears, with each
        // digit rolling into place ticker-style (no count-up sweep).
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { appeared = true }
        rollEarned = true
        Haptics.shared.tickerBurst()                        // medium ticks while it rolls
        try? await Task.sleep(nanoseconds: 1_600_000_000)   // let the roll settle

        // The coin morphs into the bolt (sped up so it lands quickly), with only
        // a brief hold so the disintegration starts ~2s sooner.
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Phase 2 — Instantly added to your balance. The pill flies in as the
        // bolt finishes forming.
        withAnimation(.easeInOut(duration: 0.45)) { phase = .added }
        // Subtle anticipation: the solid number scales up and drifts up slowly,
        // leading into (and continuing through the start of) the particle
        // conversion. Purely cosmetic — the particles themselves are unchanged.
        if textLiftEnabled {
            withAnimation(.easeOut(duration: 1.1)) {
                numberZoom = 1.06
                numberLift = -28          // clearer upward drift, not just scale
            }
        }
        // Start the particle conversion almost immediately, so the text is
        // visibly scaling/lifting while the particles are already forming.
        try? await Task.sleep(nanoseconds: 120_000_000)

        // The number disintegrates DIRECTLY into fine particles (no count to
        // zero) that stream up into the balance pill — Apple-Wallet style. The
        // particle layer takes over from the number in the same instant, then
        // the balance counts up as the particles arrive and the heading fades in.
        dissolveDots = makeDissolveDots()
        dissolveStart = Date()
        Haptics.shared.startContinuousLow()                 // low rumble while particles move
        // The solid number stays put; a mask sweeps up through it, "eating" it
        // from the bottom. Particles are born exactly along that sweep line, so
        // the text converts to particles row by row, bottom to top.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(dissolveWaveStart * 1_000_000_000))
            withAnimation(.linear(duration: dissolveWaveSpread)) { dissolveProgress = 1 }
        }
        // Once the particles are rising, the pill springs in from nothing at a
        // balance of 0, then rolls the balance up as they arrive.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)   // particles have started up
            withAnimation(.spring(response: 0.42, dampingFraction: 0.56)) { pillShown = true }
            try? await Task.sleep(nanoseconds: 260_000_000)   // show 0 for a beat
            await stepCount(to: 5_790, steps: 46, stepNs: 32_000_000) { balanceCount = $0 }
        }
        // As soon as the number has finished converting to particles, reveal the
        // heading in place with a smooth left-to-right wipe.
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        withAnimation(.easeInOut(duration: 1.2)) { headingReveal = 1 }

        // Once the particles have gathered, the rumble ends and the border shine
        // sweeps while the pill gives a single gentle scale pulse.
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        Haptics.shared.stopContinuous()
        shineActive = true
        withAnimation(.linear(duration: 1.9).repeatForever(autoreverses: false)) {
            shineAngle = 360
        }
        withAnimation(.easeOut(duration: 0.28)) { pillPulse = 1.07 }
        try? await Task.sleep(nanoseconds: 280_000_000)
        withAnimation(.easeInOut(duration: 0.5)) { pillPulse = 1.0 }
        try? await Task.sleep(nanoseconds: 2_700_000_000)

        // Phase 3 — crossfade into the trip card and play its entrance.
        withAnimation(.easeInOut(duration: 0.55)) { phase = .trip }
        try? await Task.sleep(nanoseconds: 120_000_000)
        entranceTrigger = 1
        try? await Task.sleep(nanoseconds: 550_000_000)
        withAnimation(.easeOut(duration: 0.4)) { headingShown = true }
        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(.easeOut(duration: 0.45)) { bodyShown = true }
    }

    /// Steps an integer from `start` to `target`, assigning each value via
    /// `set` so a plain `Text` reads as a counter (the clean rolling ticker).
    private func stepCount(from start: Int = 0, to target: Int, steps: Int,
                           stepNs: UInt64, _ set: (Int) -> Void) async {
        for i in 0...steps {
            set(start + (target - start) * i / steps)
            try? await Task.sleep(nanoseconds: stepNs)
        }
        set(target)
    }

    // MARK: - Rewards screens (phases 1 & 2)

    private var rewardsScreen: some View {
        ZStack {
            LinearGradient(
                colors: [rewardsBgTop, DesignColors.tripCardGradientBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                // Absolute layout mirrors the Figma 390×840 frames (nodes
                // 3377:8172 earned + 3377:8818 added). Art sits up top; the
                // number + label centre below it.
                let artCenterY: CGFloat = 59 + 283 / 2     // 200.5
                let numberY: CGFloat = 352 + 40            // big number centre
                let labelY: CGFloat = 444 + 36             // "Travel rewards earned"
                // Balance pill pinned to the top: 20px below the top edge.
                let pill = CGPoint(x: w / 2, y: 20 + 30)

                // Sweep mask for the number: a top-aligned window whose bottom
                // edge climbs from the glyph bottom up past the glyph top, so the
                // solid text is "eaten" bottom-to-top in step with the particles.
                let numBoxH: CGFloat = 78
                let lineFull = numBoxH / 2 + bandBottom
                let lineEnd = numBoxH / 2 + bandTop - 3
                let numberMaskH = dissolveStart == nil
                    ? numBoxH
                    : max(0, lineFull - dissolveProgress * (lineFull - lineEnd))

                ZStack {
                    // The scapía coin plays its full clip once — it spins, then
                    // morphs into the energy bolt (the gif's final frame). No
                    // separate static bolt; the video does the whole transition.
                    LoopingVideoView(resource: "ScapiaCoin", ext: "mp4",
                                     playOnce: true, rate: 0.75)
                        .frame(width: 237, height: 283)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .scaleEffect(appeared ? 1 : 0.85)
                        .opacity(appeared ? 1 : 0)
                        .position(x: w / 2, y: artCenterY)

                    // Earned amount — appears with each digit rolling into place,
                    // then the sweep mask "eats" it bottom-to-top as it converts
                    // to particles.
                    RollingNumberView(value: 32_800, roll: rollEarned,
                                      font: DesignFont.black(64), color: rewardsTextWhite)
                        .mask(
                            Rectangle()
                                .frame(height: numberMaskH)
                                .frame(maxWidth: .infinity, maxHeight: .infinity,
                                       alignment: .top)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
                        // Subtle anticipation: scale up & drift up just before
                        // dissolving (cosmetic; does not affect the particles).
                        .scaleEffect(textLiftEnabled ? numberZoom : 1, anchor: .center)
                        .opacity(appeared && numberShown ? 1 : 0)
                        .position(x: w / 2,
                                  y: numberY + (textLiftEnabled ? numberLift : 0))

                    // "Travel rewards earned" — earned phase only.
                    Text("Travel rewards earned")
                        .font(DesignFont.semibold(28))
                        .foregroundColor(rewardsLabel)
                        .multilineTextAlignment(.center)
                        .frame(width: 241)
                        .opacity(phase == .earned && appeared ? 1 : 0)
                        .position(x: w / 2, y: labelY)

                    // "Instantly added to your balance" — once the number has
                    // finished converting to particles, it appears in place with
                    // a smooth left-to-right wipe (no movement, just revealing).
                    Text("Instantly added to your balance")
                        .font(DesignFont.bold(32))
                        .foregroundColor(rewardsLabel)
                        .multilineTextAlignment(.center)
                        .lineSpacing(40 - 32 * 1.2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 301)
                        .mask(
                            // A feathered white mask that SLIDES left → right
                            // (offset is animatable, unlike gradient stops), so
                            // the text is revealed from the left, each part
                            // easing in softly at the moving edge.
                            GeometryReader { g in
                                let tw = g.size.width
                                let feather: CGFloat = 150
                                HStack(spacing: 0) {
                                    Rectangle().fill(Color.white).frame(width: tw)
                                    // Long, eased falloff: fully shown → mid →
                                    // faint → none, so the moving edge is soft.
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0),
                                            .init(color: .white.opacity(0.85), location: 0.22),
                                            .init(color: .white.opacity(0.5), location: 0.5),
                                            .init(color: .white.opacity(0.18), location: 0.78),
                                            .init(color: .clear, location: 1),
                                        ],
                                        startPoint: .leading, endPoint: .trailing)
                                        .frame(width: feather)
                                }
                                .frame(width: tw + feather, alignment: .leading)
                                .offset(x: -(tw + feather) + (tw + feather) * headingReveal)
                            }
                        )
                        .position(x: w / 2, y: numberY)

                    // Particle disintegration — the number's glyphs break into
                    // fine particles that stream up into the balance pill.
                    if let start = dissolveStart {
                        ParticleDissolveView(
                            dots: dissolveDots,
                            center: CGPoint(x: w / 2, y: numberY),
                            target: pill,
                            start: start,
                            white: Color.white,
                            gold: alertAmber)
                        .allowsHitTesting(false)
                    }

                    // Top balance pill — springs in (from scale 0) once the
                    // particles begin rising, then rolls the balance up. It also
                    // breathes (scale pulse) while the border shine runs.
                    balancePill(balanceCount)
                        .scaleEffect(pillShown ? pillPulse : 0)
                        .opacity(pillShown ? 1 : 0)
                        .position(pill)
                }
            }
        }
    }

    private func balancePill(_ value: Int) -> some View {
        HStack(spacing: 8) {
            Image("PillCoin")
                .resizable().interpolation(.high)
                .frame(width: 32, height: 32)
            Text(grouped(value))
                .font(DesignFont.extraBold(24))
                .foregroundColor(balanceInk)
                .tracking(0.96)
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(width: 152, height: 52)
        .background(Capsule().fill(Color.white))
        // 4px warm ring picked up from the orange gradient (Figma 3044:1678).
        .padding(4)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [DesignColors.rewardsGradientTop.opacity(0.55),
                             DesignColors.tripCardGradientBottom.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom)
            )
        )
        // A glassy white shine on the border once the particles have gathered:
        // a faint constant glass rim, plus a broad soft gleam with a crisp bright
        // core that glides around the edge like light catching glass.
        .overlay(
            ZStack {
                // Constant faint glass rim.
                Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)

                let gleam = AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0),    location: 0.0),
                        .init(color: .white.opacity(0),    location: 0.32),
                        .init(color: .white.opacity(0.35), location: 0.42),
                        .init(color: .white,               location: 0.49),
                        .init(color: .white,               location: 0.51),
                        .init(color: .white.opacity(0.35), location: 0.58),
                        .init(color: .white.opacity(0),    location: 0.68),
                        .init(color: .white.opacity(0),    location: 1.0),
                    ]),
                    center: .center,
                    angle: .degrees(shineAngle))
                Capsule().strokeBorder(gleam, lineWidth: 8).blur(radius: 6)   // soft bloom
                Capsule().strokeBorder(gleam, lineWidth: 2.5)                 // crisp gleam
            }
            .opacity(shineActive ? 1 : 0)
        )
        .shadow(color: .white.opacity(0.64), radius: 22)
    }

    private func grouped(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Trip screen (phase 3)

    private var tripScreen: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                heading
                    .padding(.top, 14)
                    .opacity(headingShown ? 1 : 0)

                Spacer(minLength: 0).frame(height: 26)

                tripCard
                    .modifier(EntranceEffect(trigger: entranceTrigger, w: cardW, h: cardH))

                Spacer(minLength: 0).frame(height: 24)

                Text("Special perk for your London trip")
                    .font(DesignFont.regular(14))
                    .foregroundColor(.black.opacity(0.56))
                    .opacity(bodyShown ? 1 : 0)

                Spacer(minLength: 0).frame(height: 12)

                offerCard
                    .opacity(bodyShown ? 1 : 0)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Close button — top-right.
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(Circle().fill(closeBG))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .padding(.top, 14)
        }
    }

    private var heading: some View {
        Text("Your flight is successfully booked")
            .font(DesignFont.bold(24))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .lineSpacing(32 - 24 * 1.2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 272)
    }

    // MARK: - Trip card

    private var tripCard: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [cardMint.opacity(0.5),
                                 DesignColors.tripCardGradientBottom.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom)
                )

            VStack(spacing: 8) {
                tripDetails
                    .frame(width: 310, height: 321)
                coinsPill
                    .frame(width: 302, height: 52)
            }
            .padding(.top, 8)
        }
        .frame(width: cardW, height: cardH)
        .shadow(color: .black.opacity(0.12), radius: 87, x: 0, y: 0)
    }

    private var tripDetails: some View {
        VStack(spacing: 0) {
            // Plane image area.
            ZStack {
                imageBG
                Image("FlightPlane")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 204)
            }
            .frame(height: 113)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    deltaLogo
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Text("PNR:")
                            .font(DesignFont.regular(12))
                            .foregroundColor(.black.opacity(0.6))
                        Text("ASD62D")
                            .font(DesignFont.regular(12))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.33),
                                                  style: StrokeStyle(lineWidth: 1, dash: [3]))
                            )
                    }
                }

                Text("London to Delhi")
                    .font(DesignFont.semibold(20))
                    .foregroundColor(.black)

                HStack(spacing: 4) {
                    Image("CalendarIcon")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text("June 27, Sunday")
                        .font(DesignFont.regular(14))
                        .foregroundColor(.black.opacity(0.6))
                }

                Text("Name 1, Name 2")
                    .font(DesignFont.regular(12))
                    .foregroundColor(.black.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer(minLength: 0)

            // View booking details — dark pill, centred.
            HStack(spacing: 4) {
                Text("View booking details")
                    .font(DesignFont.medium(14))
                    .foregroundColor(.white)
                Image("ArrowRight")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .padding(.vertical, 12)
            .background(Capsule().fill(navy))
            .padding(.bottom, 16)
        }
        .frame(width: 310, height: 321)
        .background(detailBG)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var deltaLogo: some View {
        Image("EmiratesLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 90)
    }

    private var coinsPill: some View {
        HStack(spacing: 8) {
            Image("PillCoin")
                .resizable().interpolation(.high)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 0) {
                Text("Coins earned")
                    .font(DesignFont.medium(14))
                    .foregroundColor(.black.opacity(0.8))
                HStack(spacing: 0) {
                    Image("BoltFill")
                        .resizable()
                        .frame(width: 12, height: 12)
                    Text("Instantly added")
                        .font(DesignFont.regular(12))
                        .foregroundColor(alertAmber)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 0) {
                Text("5,790")
                    .font(DesignFont.medium(14))
                    .foregroundColor(.black)
                    .tracking(0.56)
                Text("Worth Rs1152")
                    .font(DesignFont.regular(10))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 20)
        .frame(width: 302, height: 52)
        .background(Capsule().fill(Color.white))
    }

    // MARK: - Offer card

    private var offerCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)

            // Left image region.
            ZStack {
                offerBG
                Image("StayHut")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 210)
                    .offset(x: -8)
            }
            .frame(width: 170, height: 177)
            .clipped()

            // Right text.
            Text("Flat ₹2,500 off on your stay")
                .font(DesignFont.semibold(14))
                .foregroundColor(green)
                .lineSpacing(20 - 14 * 1.2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 147, alignment: .leading)
                .position(x: 186 + 147 / 2, y: 16 + 20)

            Text("Explore from 1000+ stays")
                .font(DesignFont.regular(12))
                .foregroundColor(.black.opacity(0.8))
                .lineSpacing(16 - 12 * 1.2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 140, alignment: .leading)
                .position(x: 186 + 140 / 2, y: 60 + 16)

            // Countdown, bottom-right.
            VStack(alignment: .leading, spacing: 2) {
                Text("REWARD EXPIRES IN")
                    .font(DesignFont.regular(10))
                    .tracking(1)
                    .foregroundColor(.black.opacity(0.55))
                Text(countdownText)
                    .font(DesignFont.medium(14))
                    .foregroundColor(DesignColors.textHighEmphasis)
            }
            .frame(width: 140, alignment: .leading)
            .position(x: 186 + 140 / 2, y: 127 + 19)
        }
        .frame(width: 358, height: 177)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 40, x: 0, y: 0)
    }

    private var countdownText: String {
        let h = secondsLeft / 3600
        let m = (secondsLeft % 3600) / 60
        let s = secondsLeft % 60
        return String(format: "%02d : %02d : %02d", h, m, s)
    }
}

// MARK: - Rolling ticker number (one-shot reveal)

/// Displays a fixed amount whose digits roll into place ticker-style when
/// `roll` flips true — the number simply appears, it does not count up.
private struct RollingNumberView: View {
    let value: Int
    let roll: Bool
    let font: Font
    let color: Color
    var digitWidth: CGFloat = 41
    var digitHeight: CGFloat = 78
    var commaWidth: CGFloat = 20

    private var chars: [Character] {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return Array(f.string(from: NSNumber(value: value)) ?? "\(value)")
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                if ch.isNumber, let d = ch.wholeNumberValue {
                    RollingDigit(digit: d, width: digitWidth, height: digitHeight,
                                 font: font, color: color, roll: roll,
                                 delay: Double(idx) * 0.07)
                } else {
                    Text(String(ch))
                        .font(font)
                        .foregroundColor(color)
                        .frame(width: commaWidth, height: digitHeight, alignment: .center)
                }
            }
        }
        .fixedSize()
    }
}

/// A single digit column: a 0–9–0–9 strip that rolls up to land on `digit`.
private struct RollingDigit: View {
    let digit: Int
    let width: CGFloat
    let height: CGFloat
    let font: Font
    let color: Color
    let roll: Bool
    let delay: Double

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<20, id: \.self) { i in
                Text("\(i % 10)")
                    .font(font)
                    .foregroundColor(color)
                    .frame(width: width, height: height)
            }
        }
        // roll == false → row 0 ("0"); true → row (10 + digit), a full spin
        // before settling on the target digit.
        .offset(y: roll ? -CGFloat(10 + digit) * height : 0)
        .frame(width: width, height: height, alignment: .top)
        .clipped()
        .animation(.spring(response: 1.0, dampingFraction: 0.82).delay(delay), value: roll)
    }
}

// MARK: - Particle disintegration

/// One particle sampled from a glyph pixel.
private struct DissolveDot {
    let origin: CGPoint      // start, relative to the number's centre
    let orbitAngle: Double   // base angle on the halo ellipse around the pill
    let orbitA: CGFloat      // horizontal radius
    let orbitB: CGFloat      // vertical radius
    let orbitSpeed: Double   // slow drift (rad/s) around the pill once settled
    let settles: Bool        // stays as the halo, or fades out on arrival
    let arc: CGFloat         // sideways bow along the path
    let size: CGFloat
    let gold: Bool
    let delay: Double
    let dur: Double
    let jamp: CGFloat        // settle jitter amplitude ("riddle")
    let jfreq: Double
    let jphase: Double
    let twFreq: Double        // twinkle frequency
    let twPhase: Double
}

/// Rasterises a glyph and returns the centres of its opaque pixels (relative to
/// the glyph's centre, in points) — used to build a particle cloud shaped like
/// the actual number.
private enum GlyphSampler {
    @MainActor
    static func points(text: String, fontName: String, fontSize: CGFloat,
                       maxCount: Int) -> [CGPoint] {
        let font = UIFont(name: fontName, size: fontSize)
            ?? .systemFont(ofSize: fontSize, weight: .black)
        let attrs: [NSAttributedString.Key: Any] = [.font: font,
                                                     .foregroundColor: UIColor.white]
        let astr = NSAttributedString(string: text, attributes: attrs)
        var size = astr.size()
        size.width = ceil(size.width) + 4
        size.height = ceil(size.height) + 4
        let scale: CGFloat = 2
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return [] }

        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        // Flip into UIKit's top-left origin so text draws upright.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scale, y: -scale)
        UIGraphicsPushContext(ctx)
        astr.draw(at: CGPoint(x: 2, y: 2))
        UIGraphicsPopContext()

        guard let data = ctx.data else { return [] }
        let buf = data.bindMemory(to: UInt8.self, capacity: w * h)
        // Step so total opaque samples land near maxCount (≈ glyph covers ~35%).
        let step = max(2, Int((Double(w * h) * 0.35 / Double(maxCount)).squareRoot()))
        var pts: [CGPoint] = []
        var y = 0
        while y < h {
            var x = 0
            while x < w {
                if buf[y * w + x] > 110 {
                    pts.append(CGPoint(x: CGFloat(x) / scale - size.width / 2,
                                       y: CGFloat(y) / scale - size.height / 2))
                }
                x += step
            }
            y += step
        }
        return pts
    }
}

/// Draws the disintegrating particles each frame via a `Canvas`, so hundreds of
/// fine particles animate smoothly. Each particle holds its glyph position until
/// its stagger delay, then eases up toward the pill, bowing slightly and fading.
private struct ParticleDissolveView: View {
    let dots: [DissolveDot]
    let center: CGPoint
    let target: CGPoint
    let start: Date
    let white: Color
    let gold: Color

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, _ in
                let t = tl.date.timeIntervalSince(start)
                for d in dots {
                    // A particle is "born" only when the sweep line reaches its
                    // row; until then the solid (masked) text still covers it.
                    let life = t - d.delay
                    if life <= 0 { continue }
                    let prog = min(life / d.dur, 1)
                    let sx = center.x + d.origin.x
                    let sy = center.y + d.origin.y
                    // The settle point slowly orbits the pill, so the gathered
                    // particles keep drifting around it.
                    let oa = d.orbitAngle + d.orbitSpeed * t
                    let gx = target.x + CGFloat(cos(oa)) * d.orbitA
                    let gy = target.y + CGFloat(sin(oa)) * d.orbitB

                    let x: CGFloat, y: CGFloat, op: Double, r: CGFloat
                    if prog < 1 {
                        // Travel: ease up toward the (slowly moving) settle point.
                        let e = 1 - pow(1 - prog, 3)
                        x = sx + (gx - sx) * e + d.arc * sin(prog * .pi)
                        y = sy + (gy - sy) * e
                        let bornOp = min(life / 0.1, 1)    // quick fade-in at birth
                        // Particles that won't settle fade out as they reach the
                        // pill, so the dense rise leaves only a light halo behind.
                        let arriveFade = d.settles ? 1.0
                            : (prog < 0.65 ? 1.0 : max(0, 1 - (prog - 0.65) / 0.35))
                        op = bornOp * arriveFade
                        r = d.size * (1 - 0.2 * prog)
                    } else {
                        if !d.settles { continue }         // absorbed; gone
                        // Settled: slowly drift around the pill (via `oa`) plus a
                        // gentle jitter ("riddle") and a twinkle. They stay.
                        let st = life - d.dur
                        x = gx + CGFloat(sin(t * d.jfreq + d.jphase)) * d.jamp
                        y = gy + CGFloat(cos(t * d.jfreq * 1.2 + d.jphase)) * d.jamp
                        let twinkle = 0.5 + 0.5 * sin(t * d.twFreq + d.twPhase)
                        let settleIn = min(st / 0.25, 1)   // ease into the twinkle
                        // Settle to ~40% opacity (with a gentle twinkle), easing
                        // down from full as it arrives.
                        op = (1 - settleIn) + settleIn * (0.4 * (0.7 + 0.3 * twinkle))
                        r = d.size * 0.85
                    }
                    if op <= 0.02 { continue }
                    let rect = CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)
                    let base = d.gold ? gold : white
                    ctx.fill(Path(ellipseIn: rect), with: .color(base.opacity(op)))
                }
            }
        }
    }
}

// MARK: - Trip-card warp-in entrance

private struct EntranceEffect: ViewModifier {
    let trigger: Int
    let w: CGFloat
    let h: CGFloat

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: EntranceState(), trigger: trigger) { view, s in
            let rendered = s.warp > 0.001
                ? AnyView(view.distortionEffect(
                    ShaderLibrary.cardWarp(.float2(w, h), .float(s.warp)),
                    maxSampleOffset: CGSize(width: 32, height: 0)))
                : AnyView(view)
            rendered
                .scaleEffect(s.scale, anchor: .bottom)
                .rotation3DEffect(.degrees(s.rotation), axis: (x: 1, y: 0, z: 0),
                                  anchor: .bottom, perspective: 1.0)
                .offset(y: s.offsetY)
                .opacity(s.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.offsetY) {
                CubicKeyframe(-30, duration: 0.55)
                CubicKeyframe(0, duration: 0.45)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.8, duration: 0.55)
                CubicKeyframe(1.0, duration: 0.45)
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(0, duration: 0.9)
            }
            KeyframeTrack(\.warp) {
                CubicKeyframe(0.2, duration: 0.55)
                CubicKeyframe(0, duration: 0.45)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.3)
            }
        }
    }
}

private struct EntranceState {
    var offsetY: CGFloat = 600
    var scale: CGFloat = 0.2
    var rotation: Double = -45
    var warp: CGFloat = 1
    var opacity: Double = 0
}

#Preview {
    TripAnnouncementViewV2()
}
