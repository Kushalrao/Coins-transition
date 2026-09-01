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
import AVFoundation

// The confirmation can celebrate any booking type. Flight keeps the original
// card; stay/experience use contextual photos; train/bus use the design's
// illustrations (Figma 4901:8538, 4901:8882, 5607:2128, 5614:10117).
enum BookingKind: String, CaseIterable {
    case flight, stay, experience, train, bus

    var noun: String { rawValue }

    var image: String {
        switch self {
        case .flight:     return "FlightPlane"
        case .stay:       return "hotel_dabaixa"
        case .experience: return "booking_kayak"
        case .train:      return "booking_train"
        case .bus:        return "booking_bus"
        }
    }

    var caption: String? {
        switch self {
        case .train: return "CDG SKRANTI EXP • 22685"
        case .bus:   return "NTC Nagpur Travels"
        default:     return nil
        }
    }

    /// The confirmation heading. Flights name the destination, which reads
    /// better than the generic noun now that the flow always confirms a flight.
    var confirmation: String {
        switch self {
        case .flight: return "Your flight to Zurich is successfully booked"
        default:      return "Your \(noun) is successfully booked"
        }
    }

    var title: String {
        switch self {
        case .flight:     return "Trip to Switzerland"
        case .stay:       return "Hotel Schweizerhof, Lucerne"
        case .experience: return "Benagil: Caves, Beaches, and Secret Spots Guided Kayak Tour"
        case .train:      return "Bengaluru to Chandigarh"
        case .bus:        return "Bengaluru to Thiruvananthpuram"
        }
    }

    var subtitle: String? {
        self == .stay ? "Deluxe King room" : nil
    }

    var date: String {
        switch self {
        case .flight:     return "19 Dec, Saturday"
        case .stay:       return "24 Apr - 3 May"
        case .experience: return "26 Apr"
        case .train, .bus: return "27 Aug"
        }
    }

    var showsNames: Bool { self != .stay }
}

struct TripAnnouncementViewV2: View {
    // Booking type for this confirmation. The flow now reaches this screen
    // from the flight review page's "Pay now", so the confirmation is always a
    // flight — the previous uniform draw over all kinds could show a train
    // confirmation for a flight the user had just paid for.
    //
    // Still debug-overridable via the "bookingKind" default
    // (launch args: -bookingKind train) to exercise the other artwork.
    @State private var kind: BookingKind = {
        if let s = UserDefaults.standard.string(forKey: "bookingKind"),
           let k = BookingKind(rawValue: s) { return k }
        return .flight
    }()


    /// Called when the user taps "View booking details" on the trip card.
    var onViewBookingDetails: () -> Void = {}
    /// The offers pill goes to the same place as "View trip", but asks the trip
    /// page to present its offers sheet once it has settled.
    var onViewOffers: () -> Void = {}

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
    // Dead air between the number finishing its lift and the sweep starting.
    // The lift is an ease-out, so it does most of its travel early and then
    // creeps — with 0.18 here the number looked stationary for a quarter of a
    // second before anything happened to it. Cut to a beat, so the glyphs start
    // breaking apart while they are still rising.
    private let dissolveWaveStart: Double = 0.04
    private let dissolveWaveSpread: Double = 0.317
    /// How far the number drifts up as it breaks apart, and how long the lift
    /// leads the sweep by. Both are read by `makeDissolveDots` to work out what
    /// the number was doing at the instant each particle came off it.
    private let numberLiftDistance: CGFloat = 28
    private let liftLead: Double = 0.06

    // Trip-card reveal state
    @State private var entranceTrigger = 0
    @State private var headingShown = false
    @State private var bodyShown = false
    @State private var confettiStart: Date? = nil   // confetti bursts once the trip screen loads
    @State private var rippleTrigger = 0            // per-character ripple on the offers pill text
    @State private var bloomProgress: CGFloat = 0   // aurora sweep, 0 → 1 from 2.0s
    @State private var artOpacity: Double = 1       // coin clip clears out for the cloud
    /// Fixed at first render so the bloom's drift is one continuous clock for
    /// the life of the screen rather than restarting on every state change.
    @State private var sequenceStart = Date()
    @State private var bloomIn: CGFloat = 0         // classic: bottom bloom grows in
    @State private var bloomExit: CGFloat = 0       // classic: bottom bloom leaves upward
    @State private var contentScale: CGFloat = 1    // classic: content shrinks while it goes

    private let cardW: CGFloat = 326
    private let cardH: CGFloat = 401

    // MARK: Colors (Figma node 3183:10291)
    private let bgTop = Color(red: 1.0, green: 0xF8 / 255, blue: 0xEE / 255)        // #FFF8EE
    private let bgBottom = Color(red: 0xF7 / 255, green: 0xF9 / 255, blue: 0xF4 / 255) // #F7F9F4
    private let detailBG = Color(red: 0xF8 / 255, green: 0xFA / 255, blue: 0xF5 / 255) // #F8FAF5
    private let imageBG = Color(red: 0xFE / 255, green: 0xF8 / 255, blue: 0xE9 / 255)  // #FEF8E9
    private let navy = Color(red: 0x03 / 255, green: 0x12 / 255, blue: 0x23 / 255)     // #031223
    private let green = Color(red: 0x38 / 255, green: 0x9E / 255, blue: 0x0D / 255)    // #389E0D
    private let pillNavy = Color(red: 0x0B / 255, green: 0x26 / 255, blue: 0x45 / 255)  // #0B2645 Secondary/Blue/800
    private let closeBG = Color(red: 0xE9 / 255, green: 0xEB / 255, blue: 0xE7 / 255)  // #E9EBE7
    private let balanceInk = Color(red: 0x14 / 255, green: 0x1C / 255, blue: 0x20 / 255) // #141C20
    // Trip-card background gradient (Figma 3223:2067) — mint → yellow, 50% alpha.
    private let cardMint = Color(red: 0xBD / 255, green: 0xE3 / 255, blue: 0xDF / 255)   // #BDE3DF
    private let alertAmber = Color(red: 0xD4 / 255, green: 0x88 / 255, blue: 0x06 / 255)  // #D48806
    // Amount + labels on the coins screens: Neutral/Grey/900 (Figma 4740:13088).
    // Near-black, because the lilac/blush field is far too pale to carry the
    // white and cream this screen used against its old orange background.
    private let rewardsInk = Palette.grey900

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
        // Each particle aims at a point on an ellipse hugging the pill, so the
        // cloud converges loosely on it rather than on a single pixel. Nothing
        // stays: every particle is gone by the time it arrives.
        let ys = origins.map(\.y)
        let minY = ys.min()!, maxY = ys.max()!
        let span = max(1, maxY - minY)
        bandTop = minY
        bandBottom = maxY
        // One particle per sampled glyph pixel. This was 3, which read as a
        // solid mass once the plume path stopped fanning them across the
        // screen and kept each column over its own glyph.
        return origins.flatMap { o -> [DissolveDot] in
            (0..<1).compactMap { _ -> DissolveDot? in
                if Double.random(in: 0...1) < 0.2 { return nil }   // drop 20% of total
                let jx = CGFloat.random(in: -2.5...2.5)
                let jy = CGFloat.random(in: -2.5...2.5)
                let frac = Double((maxY - o.y) / span)   // 0 = bottom, 1 = top
                let ang = Double.random(in: 0 ..< (2 * .pi))
                let rr = CGFloat.random(in: 0...14)      // tight band hugging the pill
                // Terminal velocity rises with particle size, so the coarse
                // ones outrun the fine dust instead of the whole cloud moving
                // as one sheet. The exponent sits between Stokes (v ∝ r²) and
                // Newton (v ∝ √r) drag and is tempered for legibility: true
                // Stokes over a 2x size range would spread flight times 4x and
                // strand the smallest particles long after the beat.
                //
                // Referenced to the middle of the size range, so the cloud's
                // average pace is exactly what it was — only its spread changes.
                let size = CGFloat.random(in: 2.0...4.0)
                let drag = pow(3.0 / Double(size), 0.55)   // 1.25x at 2pt … 0.85x at 4pt

                // A fragment leaves with the momentum of the body it broke off.
                // The number is still rising when the sweep reaches its lowest
                // rows, so those particles are born already moving; by the time
                // the sweep reaches the top the lift has run out and the last
                // rows start from rest. That gradient is free stratification on
                // top of the size coupling, and it is what stops the break-up
                // reading as particles spawning where the number used to be.
                //
                // Small embers cool fastest, so the fine dust runs to the
                // deeper amber and only the coarse particles stay hot and
                // bright. Green stays an independent accent — it is a hue in
                // the palette, not a step on the brightness ramp — and the
                // amber/deep split is a soft bias rather than a threshold, so
                // the ramp reads as a gradient across the cloud instead of two
                // separate populations. The odds are set to land on the same
                // 40/30/30 mix the repeated palette used to give.
                let heat = Double((size - 2.0) / 2.0)        // 0 fine … 1 coarse
                let tint = Double.random(in: 0...1) < 0.3
                    ? 2                                       // green accent
                    : (Double.random(in: 0...1) < 0.32 + 0.5 * heat ? 0 : 1)

                // The lift is a SwiftUI `.easeOut`, near enough a quadratic:
                // speed peaks at twice the mean and falls off linearly.
                let delay = dissolveWaveStart + frac * dissolveWaveSpread
                    + Double.random(in: 0...0.04)
                let liftU = min(1, max(0, (delay + liftLead) / dissolveWaveSpread))
                let liftPeak = 2 * numberLiftDistance / CGFloat(dissolveWaveSpread)
                let born = (textLiftEnabled && CoinsVariant.active.showsParticles)
                    ? liftPeak * CGFloat(1 - liftU) : 0

                return DissolveDot(
                    origin: CGPoint(x: o.x + jx, y: o.y + jy),
                    // On an ellipse roughly the size of the pill's border.
                    aim: CGPoint(x: CGFloat(cos(ang)) * (82 + rr),
                                 y: CGFloat(sin(ang)) * (32 + rr)),
                    // A gentle outward lean as the column rises — the plumes
                    // splay a little with height rather than bowing across the
                    // screen. This used to be ±30…85, which threw every particle
                    // sideways and turned the columns into one wide bouquet.
                    arc: (o.x >= 0 ? 1 : -1) * CGFloat.random(in: 4...15)
                        + CGFloat.random(in: -3...3),
                    // Where it drifts once the cloud loosens over the last
                    // stretch: outward from its own column and still climbing,
                    // so the plumes fray apart as they thin instead of being
                    // drawn tight into the pill.
                    loosenX: (o.x >= 0 ? 1 : -1) * CGFloat.random(in: 10...44)
                        + CGFloat.random(in: -8...8),
                    loosenY: CGFloat.random(in: -34 ... -6),
                    size: size,
                    tint: tint,
                    // birth time tracks the sweep line as it reaches this row
                    delay: delay,
                    birthSpeed: born,
                    // Flight time ramps with birth order rather than being
                    // random: the first particles off the bottom of the glyphs
                    // move quickest and the last ones drift, so the cloud
                    // leaves briskly and settles slowly. The last-born take
                    // 1.4x the time of the first — the 0.4 spread — and the
                    // base is scaled so the slowest still lands at exactly the
                    // moment they did before, leaving the phase length alone.
                    //
                    // The random band is deliberately narrow. Widen it and the
                    // jitter starts outweighing the ramp — a first-born can end
                    // up slower than a last-born and the deceleration stops
                    // reading at all.
                    dur: Double.random(in: 0.542...0.594) * (1 + 0.4 * frac) * drag
                )
            }
        }
    }

    var body: some View {
        ZStack {
            rewardsScreen
                .opacity(phase == .trip ? 0 : 1)

            tripScreen
                .opacity(phase == .trip ? 1 : 0)
        }
        .task { await runSequence() }
    }

    // MARK: - Sequence orchestration

    private func runSequence() async {
        // classic: the bottom bloom runs on its own clock, absolute from t=0,
        // so its beats are readable as wall-clock times instead of being
        // threaded through the main chain's relative sleeps.
        if CoinsVariant.active.usesBottomBloom {
            Task { @MainActor in
                // 0.30 — grows up out of the bottom edge rather than being there.
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.spring(response: 1.04, dampingFraction: 0.82)) { bloomIn = 1 }
                // 2.80 — content gives way 0.2s ahead of the launch, so the
                // shrink reads as a reaction to it rather than a consequence.
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.easeIn(duration: 0.25)) { contentScale = 0.88 }
                // 3.00 — swells to 1.4x and leaves, accelerating all the way.
                try? await Task.sleep(nanoseconds: 200_000_000)
                withAnimation(.timingCurve(0.45, 0, 1, 1, duration: 0.7)) { bloomExit = 1 }
                // 3.45 — gone. It clears the top well before the 0.7s
                // animation nominally ends, because the 1.4x swell carries the
                // upper edge out ahead of the offset, so the content springs
                // back on the visual exit rather than the arithmetic one.
                try? await Task.sleep(nanoseconds: 450_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { contentScale = 1 }
            }
        }

        // Phase 1 — Travel rewards earned. The amount simply appears, with each
        // digit rolling into place ticker-style (no count-up sweep).
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { appeared = true }
        rollEarned = true
        RewardHaptics.shared.tickerBurst()                        // medium ticks while it rolls
        try? await Task.sleep(nanoseconds: 1_600_000_000)   // let the roll settle

        // The coin morphs into the bolt, with only a brief hold so the
        // disintegration starts ~2s sooner. Two hundred milliseconds into that
        // hold — 2.0s in — the aurora starts out of the bottom edge.
        //
        // One 3.0s driver carries the whole sweep, 2.0s → 5.0s, which brackets
        // the particle rise exactly: the first particles are born at 2.4s and
        // the last of them reach the pill around 4.9s. The aurora passes through
        // its designed Figma size about a fifth of the way up and keeps going,
        // so by the time the cloud has gathered it has flooded the screen.
        // Ease-in-out because the crest should gather pace behind the particles
        // and settle with them rather than arriving at a constant rate.
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeInOut(duration: 3.0)) { bloomProgress = 1 }
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Phase 2 — Instantly added to your balance. The pill flies in as the
        // bolt finishes forming.
        withAnimation(.easeInOut(duration: 0.45)) { phase = .added }
        // Subtle anticipation: the solid number scales up and drifts up slowly,
        // leading into (and continuing through the start of) the particle
        // conversion. Purely cosmetic — the particles themselves are unchanged.
        if textLiftEnabled, CoinsVariant.active.showsParticles {
            // Runs for exactly as long as the mask sweep that eats the number,
            // off the same constant — so it is not a separate hardcoded value
            // that has to be remembered every time the dissolve is re-timed.
            // It had been left at a fixed duration through three speed-ups and
            // ended up drifting slowly in front of a fast vanish.
            //
            // The sweep starts 0.10 in and the lift runs the full 0.317, so
            // the two overlap by design: the number is still rising while its
            // lower rows are already breaking up, and those particles inherit
            // the speed it had at that instant (see `birthSpeed`).
            withAnimation(.easeOut(duration: dissolveWaveSpread)) {
                numberZoom = 1.06
                numberLift = -numberLiftDistance
            }
        }
        // Start the particle conversion almost immediately, so the text is
        // visibly scaling/lifting while the particles are already forming.
        // With `dissolveWaveStart` this leaves the lift 100ms of clear
        // anticipation before the sweep reaches its first row.
        try? await Task.sleep(nanoseconds: UInt64(liftLead * 1_000_000_000))

        // The number disintegrates DIRECTLY into fine particles (no count to
        // zero) that stream up into the balance pill — Apple-Wallet style. The
        // particle layer takes over from the number in the same instant, then
        // the balance counts up as the particles arrive and the heading fades in.
        // Always sampled, even when the cloud is off: `makeDissolveDots` is also
        // what measures the glyph band (`bandTop`/`bandBottom`) that the mask
        // sweep is cut against, so skipping it would leave the number unable to
        // dissolve at all. Only the cloud itself is variant-dependent.
        // `makeDissolveDots` doubles as the glyph-band measurement the mask sweep
        // is cut against — but the skew exit holds the mask open, so with the
        // particles off there is nothing left that needs the sampling and the
        // raster can be skipped entirely.
        dissolveDots = CoinsVariant.active.showsParticles ? makeDissolveDots() : []
        dissolveStart = Date()
        RewardHaptics.shared.startContinuousLow()                 // low rumble while particles move
        // The solid number stays put; a mask sweeps up through it, "eating" it
        // from the bottom. Particles are born exactly along that sweep line, so
        // the text converts to particles row by row, bottom to top.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(dissolveWaveStart * 1_000_000_000))
            withAnimation(.linear(duration: dissolveWaveSpread)) { dissolveProgress = 1 }
        }
        // The coin clip clears out while the cloud is in the air. Its own task,
        // so the main chain's timings are untouched. All offsets here are from
        // `dissolveStart`, not absolute — the phase has been re-timed enough
        // times that wall-clock figures in comments go stale immediately.
        //
        // Out at +0.18 as the first particles are born, clear by +0.43, and
        // back from +0.68. The return is deliberately ahead of the cloud
        // finishing at +1.44: the clip comes back through the tail of the
        // stragglers rather than waiting for an empty screen.
        if CoinsVariant.active.artFadesForParticles {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 180_000_000)
                withAnimation(.easeOut(duration: 0.25)) { artOpacity = 0 }
                try? await Task.sleep(nanoseconds: 500_000_000)
                withAnimation(.easeIn(duration: 0.35)) { artOpacity = 1 }
            }
        }
        // Once the particles are rising, the pill springs in from nothing at a
        // balance of 0, then rolls the balance up as they arrive.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)   // particles have started up
            withAnimation(.spring(response: 0.42, dampingFraction: 0.56)) { pillShown = true }
            // Holds on 0 until the first coins actually reach the pill at
            // +0.56, rather than starting the moment the pill lands — the
            // balance should be filled by the cloud, not race it.
            try? await Task.sleep(nanoseconds: 300_000_000)
            // Ends at +1.44, which is when the slowest particle arrives, the
            // rumble stops and the shine fires. The old count finished 320ms
            // before the last coins landed, so the total was already sitting
            // there while the tail was still visibly streaming in.
            await rollCount(to: 27_053, over: 0.94) { balanceCount = $0 }
        }
        // As soon as the number has finished converting to particles, reveal the
        // heading in place with a smooth left-to-right wipe.
        try? await Task.sleep(nanoseconds: 570_000_000)
        withAnimation(.easeInOut(duration: 0.75)) { headingReveal = 1 }

        // Once the particles have gathered, the rumble ends and the border shine
        // sweeps while the pill gives a single gentle scale pulse. This beat
        // is keyed to the cloud arriving rather than to a fixed moment, so it
        // moves with the flight time: the 1.2x speed-up pulled it in 127ms,
        // the 1.3x slow-down pushed it back 192ms, and coupling flight time to
        // particle size stretched the finest dust out by a further 208ms, and
        // closing the gap before the sweep pulled every birth 140ms earlier.
        try? await Task.sleep(nanoseconds: 867_000_000)
        RewardHaptics.shared.stopContinuous()
        shineActive = true
        withAnimation(.linear(duration: 1.9).repeatForever(autoreverses: false)) {
            shineAngle = 360
        }
        withAnimation(.easeOut(duration: 0.28)) { pillPulse = 1.07 }
        try? await Task.sleep(nanoseconds: 280_000_000)
        withAnimation(.easeInOut(duration: 0.5)) { pillPulse = 1.0 }
        // The settle absorbs whatever the flight time borrowed or gave back,
        // so the crossfade always hands over at 6.49 and the two variants stay
        // in step however the cloud is re-timed.
        try? await Task.sleep(nanoseconds: 2_613_000_000)

        // Phase 3 — crossfade into the trip card and play its entrance.
        withAnimation(.easeInOut(duration: 0.55)) { phase = .trip }
        try? await Task.sleep(nanoseconds: 120_000_000)
        entranceTrigger = 1
        try? await Task.sleep(nanoseconds: 550_000_000)
        withAnimation(.easeOut(duration: 0.4)) { headingShown = true }
        // The celebration leads the landing by a breath: the card's entrance
        // runs 1.0s, and the offers-unlocked reveal + ripple + confetti all
        // kick off at 0.9s — 0.1s before the card finishes settling.
        try? await Task.sleep(nanoseconds: 350_000_000)
        withAnimation(.easeOut(duration: 0.45)) { bodyShown = true }
        Haptics.light()
        confettiStart = Date()
        rippleTrigger += 1
    }

    /// Steps an integer from `start` to `target`, assigning each value via
    /// `set` so a plain `Text` reads as a counter (the clean rolling ticker).
    /// Rolls a counter to `target` over `duration`, shaped like the rate coins
    /// are actually landing: few at first, the bulk through the middle, then
    /// stragglers. A linear ramp reads as a machine ticking rather than as a
    /// balance being filled by something arriving.
    ///
    /// Driven off the clock rather than a fixed number of sleeps. `Task.sleep`
    /// guarantees only a minimum, so the old 46-step × 16ms loop ran measurably
    /// longer than the 736ms it claimed and finished at a moment nobody chose.
    private func rollCount(to target: Int, over duration: Double,
                           _ set: (Int) -> Void) async {
        let began = Date()
        var elapsed = 0.0
        while elapsed < duration {
            let p = elapsed / duration
            let eased = p * p * (3 - 2 * p)          // smoothstep
            set(Int((Double(target) * eased).rounded()))
            try? await Task.sleep(nanoseconds: 12_000_000)
            elapsed = Date().timeIntervalSince(began)
        }
        set(target)
    }

    // MARK: - Rewards screens (phases 1 & 2)

    private var rewardsScreen: some View {
        ZStack {
            // The field and the aurora sweeping up it, driven as one unit so the
            // glass crest and the bloom behind it track frame by frame. The coin
            // clip, the amount and the particle cloud all sit ABOVE this: the
            // wave is a layerEffect, and one cannot sample an AVPlayerLayer.
            // Only the field goes behind the content. The bloom itself is
            // layered over it further down, so it sweeps across the coin and
            // the amount on its way out rather than sliding away underneath.
            if CoinsVariant.active.usesBottomBloom {
                LinearGradient(
                    stops: [
                        .init(color: CoinsPalette.fieldTop, location: 0),
                        .init(color: CoinsPalette.fieldMid, location: CoinsPalette.fieldMidStop),
                        .init(color: CoinsPalette.fieldBottom, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            } else {
                AuroraBackdrop(progress: bloomProgress)
                    .ignoresSafeArea()
            }

            GeometryReader { geo in
                let w = geo.size.width
                // Absolute layout mirrors the Figma 390×840 frames (nodes
                // 3377:8172 earned + 3377:8818 added). Art sits up top; the
                // number + label centre below it.
                // Figma 6289:9268 — the art and the amount block, grouped and
                // sitting lower than the 3377:8172 frames these were originally
                // taken from. Art 235×257 at y=135; amount 241×80 at y=424;
                // label 241×60 at y=512.
                let artCenterY: CGFloat = 135 + 257 / 2    // 263.5 (was 200.5)
                let numberY: CGFloat = 424 + 80 / 2        // 464    (was 392)
                let labelY: CGFloat = 512 + 60 / 2         // 542    (was 480)
                // Balance pill pinned to the top: 20px below the top edge.
                let pill = CGPoint(x: w / 2, y: 20 + 30)

                // Sweep mask for the number: a top-aligned window whose bottom
                // edge climbs from the glyph bottom up past the glyph top, so the
                // solid text is "eaten" bottom-to-top in step with the particles.
                let numBoxH: CGFloat = 78
                let lineFull = numBoxH / 2 + bandBottom
                let lineEnd = numBoxH / 2 + bandTop - 3
                // Held at full height when the amount leaves by skewing away:
                // there are no particles for the mask to hand the glyphs over
                // to, so eating it as well would just delete it mid-flight.
                let skewExit = CoinsVariant.active.numberExitsBySkew
                let particlesOn = CoinsVariant.active.showsParticles
                // Held open unless the glyphs are actually being handed to
                // particles: eating the number with nothing to convert it into
                // would just delete it mid-air.
                let numberMaskH = (dissolveStart == nil || skewExit || !particlesOn)
                    ? numBoxH
                    : max(0, lineFull - dissolveProgress * (lineFull - lineEnd))

                ZStack {
                    // The scapía coin plays its full clip once — it spins, then
                    // morphs into the energy bolt (the clip's final frame). No
                    // separate static bolt; the video does the whole transition.
                    // The clip is art on a pure-white plate; multiply blending
                    // cancels the white against the page gradient so the coin
                    // reads as cut out. Unlike the previous clip (which had its
                    // orange backdrop baked in) this re-composites every frame,
                    // so the background underneath is free to animate.
                    LoopingVideoView(resource: "CoinRewards", ext: "mp4",
                                     gravity: .resizeAspect,
                                     playOnce: true, rate: 0.75)
                        .frame(width: 237, height: 283)
                        .blendMode(.multiply)
                        .scaleEffect(appeared ? contentScale : 0.85)
                        .opacity(appeared ? artOpacity : 0)
                        .position(x: w / 2, y: artCenterY)

                    // Earned amount — appears with each digit rolling into place,
                    // then the sweep mask "eats" it bottom-to-top as it converts
                    // to particles.
                    RollingNumberView(value: 27_053, roll: rollEarned,
                                      font: DesignFont.black(64), color: rewardsInk)
                        .scaleEffect(contentScale)
                        .mask(
                            Rectangle()
                                .frame(height: numberMaskH)
                                .frame(maxWidth: .infinity, maxHeight: .infinity,
                                       alignment: .top)
                        )
                        // No drop shadow: it existed to lift white glyphs off the
                        // old orange field, and only muddies near-black ones.
                        // Subtle anticipation: scale up & drift up just before
                        // dissolving (cosmetic; does not affect the particles).
                        .scaleEffect(textLiftEnabled ? numberZoom : 1, anchor: .center)
                        // The skew exit rides the same driver the mask sweep
                        // uses in `classic`, so the amount leaves on exactly the
                        // same curve — only the expression of it differs.
                        .modifier(SkewLift(progress: skewExit ? dissolveProgress : 0))
                        // Fades on the same curve whenever it is not being
                        // eaten by the mask — skew exit or no particles at all.
                        .opacity(appeared && numberShown
                                 ? ((skewExit || !particlesOn) ? 1 - Double(dissolveProgress) : 1)
                                 : 0)
                        .position(x: w / 2,
                                  y: numberY + (textLiftEnabled ? numberLift : 0))

                    // "Travel rewards earned" — earned phase only.
                    Text("Travel rewards earned")
                        .font(DesignFont.semibold(28))
                        .foregroundColor(rewardsInk)
                        .multilineTextAlignment(.center)
                        .frame(width: 241)
                        .scaleEffect(contentScale)
                        .opacity(phase == .earned && appeared ? 1 : 0)
                        .position(x: w / 2, y: labelY)

                    // "Instantly added to your balance" — once the number has
                    // finished converting to particles, it appears in place with
                    // a smooth left-to-right wipe (no movement, just revealing).
                    Text("Instantly added to your balance")
                        .font(DesignFont.bold(32))
                        // Ink throughout: the aurora floods this line in pale
                        // yellow, so dark type stays legible the whole way. (A
                        // white crossfade lived here while the palette ended on
                        // navy — it would be invisible on this one.)
                        .foregroundColor(rewardsInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(40 - 32 * 1.2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 301)
                        .scaleEffect(contentScale)
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
                    // Empty in the `refined` variant — gated rather than merely
                    // drawing nothing, so its TimelineView(.animation) is not
                    // left ticking every frame for the life of the screen.
                    if let start = dissolveStart, !dissolveDots.isEmpty {
                        ParticleDissolveView(
                            dots: dissolveDots,
                            center: CGPoint(x: w / 2, y: numberY),
                            target: pill,
                            start: start,
                            palette: CoinsPalette.particles)
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

            // Over the content, not under it: the bloom passes across the coin
            // and the amount as it leaves.
            if CoinsVariant.active.usesBottomBloom {
                BottomBloom(entrance: bloomIn, exit: bloomExit, start: sequenceStart)
                    .ignoresSafeArea()
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
        .frame(width: 176, height: 52)
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

            // Animated confetti — bursts up from the bottom edge, tumbles and
            // falls back out. Sits behind the page content, like the Figma comp.
            if let start = confettiStart {
                ConfettiBurstView(start: start)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                heading
                    .padding(.top, 14)
                    .opacity(headingShown ? 1 : 0)

                Spacer(minLength: 0).frame(height: 26)

                tripCard
                    .modifier(EntranceEffect(trigger: entranceTrigger, w: cardW, h: cardH))

                Spacer(minLength: 0).frame(height: 26)

                // Figma 5528:22562 — rewards caption.
                Text("Vacation rewards unlocked, save up to ₹25,000 on your vacation")
                    .font(DesignFont.regular(14))
                    .foregroundColor(.black.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .lineSpacing(22 - 14 * 1.2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 261)
                    .opacity(bodyShown ? 1 : 0)

                Spacer(minLength: 0).frame(height: 24)

                Button(action: onViewOffers) { offersUnlockedPill }
                    .buttonStyle(.plain)
                    .opacity(bodyShown ? 1 : 0)
                    .disabled(!bodyShown)

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
        Text(kind.confirmation)
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
            // Figma 5528:22494 — orange → yellow card background.
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DesignColors.tripCardGradientTop,
                                 DesignColors.tripCardGradientBottom],
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
            // Booking image area: the plane on its soft canvas for flights;
            // a contextual photo for stays/experiences; the design's
            // illustrations for train and bus (Figma 5607:2128, 5614:10117).
            ZStack {
                imageBG
                if kind == .flight {
                    Image("FlightPlane")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 204)
                } else {
                    Image(kind.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 310, height: 113)
                }
            }
            .frame(height: 113)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                if kind == .flight {
                    HStack(alignment: .center) {
                        deltaLogo
                        Spacer(minLength: 0)
                        pnrBox
                    }
                } else if let caption = kind.caption {
                    // Train/bus caption row: little transit badge + operator.
                    HStack(alignment: .center, spacing: 4) {
                        Image("booking_transit_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(caption)
                            .font(DesignFont.regular(14))
                            .foregroundColor(.black.opacity(0.6))
                        Spacer(minLength: 0)
                        if kind == .train { pnrBox }
                    }
                }

                Text(kind.title)
                    .font(DesignFont.semibold(20))
                    .foregroundColor(.black)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = kind.subtitle {
                    Text(subtitle)
                        .font(DesignFont.regular(14))
                        .foregroundColor(.black.opacity(0.6))
                }

                HStack(spacing: 4) {
                    Image("CalendarIcon")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(kind.date)
                        .font(DesignFont.regular(14))
                        .foregroundColor(.black.opacity(0.6))
                }

                if kind.showsNames {
                    Text("Name 1, Name 2")
                        .font(DesignFont.regular(12))
                        .foregroundColor(.black.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer(minLength: 0)

            // View trip — dark pill, centred. Scales down while pressed, with a
            // light haptic on touch-down (the action itself fires a medium one).
            Button(action: onViewBookingDetails) {
                HStack(spacing: 4) {
                    Text("View trip")
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
            }
            .buttonStyle(PressScaleStyle())
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

    private var pnrBox: some View {
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
                Text("27,053")
                    .font(DesignFont.medium(14))
                    .foregroundColor(.black)
                    .tracking(0.56)
                Text("Worth Rs5410")
                    .font(DesignFont.regular(10))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 20)
        .frame(width: 302, height: 52)
        .background(Capsule().fill(Color.white))
    }

    // MARK: - Offers unlocked pill (Figma 7:5356)
    //
    // White capsule now, not navy: a fanned stack of three offer cards, the
    // count, and a chevron.

    private var offersUnlockedPill: some View {
        HStack(spacing: 0) {
            offerStack
                .padding(.leading, 12)
                .offset(y: -7)          // the stack sits a touch above centre

            RippleText(text: "4 Trip offers unlocked",
                       font: DesignFont.semibold(16),
                       base: .black,
                       trigger: rippleTrigger)
                .padding(.leading, 12)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .padding(.trailing, 12)
        }
        .frame(width: 288, height: 54)
        .background(Capsule().fill(Color.white))
        .shadow(color: .black.opacity(0.16), radius: 27, y: 2)
    }

    /// Three offer cards fanned out of each other, 55.265×46.262 all told.
    /// Each is a yellow card tied in ribbon with its name on a white footer;
    /// they lean 0°, 9.52° and 22.41° and fade toward the back.
    private var offerStack: some View {
        ZStack {
            miniOffer(w: 38, h: 26.227, radius: 2.331, caption: "Schengen Visa")
                .opacity(0.45)
                .position(x: 19, y: 33.15)
            miniOffer(w: 41.548, h: 28.676, radius: 2.549, caption: "Experiences in Munich")
                .opacity(0.75)
                .rotationEffect(.degrees(9.52))
                .position(x: 23.86, y: 28.58)
            miniOffer(w: 44.851, h: 30.956, radius: 2.752, caption: "Stays in Zurich")
                .rotationEffect(.degrees(22.41))
                .position(x: 28.63, y: 22.85)
        }
        .frame(width: 55.265, height: 46.262)
    }

    /// The ribbon art is authored at almost exactly the card's aspect ratio, so
    /// it fills the card and lands its bow in the top-right corner unaided.
    private func miniOffer(w: CGFloat, h: CGFloat, radius: CGFloat, caption: String) -> some View {
        ZStack(alignment: .topLeading) {
            Color.white
            Rectangle()
                .fill(Color(hex: "FCD800"))
                .frame(width: w, height: h * 0.698)
            Text(caption)
                .font(.system(size: h * 0.088, weight: .medium))
                .foregroundColor(.black.opacity(0.7))
                .lineLimit(1)
                .padding(.leading, w * 0.06)
                .offset(y: h * 0.75)
            Image("gift_wrap")
                .resizable()
                .frame(width: w, height: h)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

// MARK: - Coins cinematic palette

/// The aurora bloom's colours (Figma 4740:13077), shared with the rising
/// particles so the disintegration and the bloom read as one system rather
/// than two unrelated effects.
private enum CoinsPalette {
    // The page field the aurora sweeps up — Figma 6277:9105: a soft gold crown
    // easing through cream to white. (Was lilac → blush; before that orange →
    // yellow, Figma 3377:8172.)
    static let fieldTop    = Color(hex: "EADDA5")
    static let fieldMid    = Color(hex: "FFEFD8")
    static let fieldBottom = Color(hex: "FFFFFF")
    /// Where the cream stop sits.
    static let fieldMidStop: CGFloat = 0.47641

    // The bloom, outermost to core. Note the ordering: the deep navy is the
    // *core* here, sitting in the mouth of the mint, rather than a band part way
    // out as in the previous palette.
    // Figma 6396:9357 — the `classic` bottom bloom. Two of its three circles
    // carry linear gradients rather than flat fills, which is what gives it
    // depth without needing a fourth disc.
    static let bloomOuterA = Color(hex: "BEF492")   // Ellipse 1177 start
    static let bloomOuterB = Color(hex: "FFF800")   // Ellipse 1177 end
    static let bloomMidA   = Color(hex: "D8F57A")   // Ellipse 1176 start
    static let bloomMidB   = Color(hex: "90FFF4")   // Ellipse 1176 end
    static let bloomCore   = Color(hex: "FFFECD")   // Ellipse 1179, solid

    static let gold   = Color(hex: "E8E19F")   // Ellipse 1177
    static let lime   = Color(hex: "D8F57A")   // Ellipse 1176
    static let mint   = Color(hex: "5CED9F")   // Ellipse 1175
    /// The innermost disc — the last colour the sweep leaves on screen, and by
    /// the end most of it. Replaced the deep navy the core used to carry.
    /// Geometry untouched. Note this is a hand-picked value, not the node's:
    /// Ellipse 1179 is `#EDEC5C`, a touch deeper.
    static let yellow = Color(hex: "FFFE94")

    // Particles, in the palette's own family. The field and bloom are gold,
    // lime and yellow, so the cloud is amber and green — taken from the design
    // system rather than invented. The dark pinks this replaces were picked
    // when the field was lilac and blush, and read as foreign over cream.
    //
    // Deliberately darker than the bloom itself: every disc colour is light,
    // and light particles over a cream-to-white ground disappear. The bloom's
    // own colours were tried early on and turned the dissolve into confetti.
    static let particleAmber = Palette.yellow500        // Alert/Yellow/500 #D48806
    static let particleDeep  = Color(hex: "AD6800")     // Alert/Yellow/600
    static let particleGreen = Palette.green500         // Success/Green/500 #389E0D

    /// The three particle colours. The mix used to be weighted by repeating
    /// entries here, because the draw site picked a uniform random index; it is
    /// chosen from particle size now, so the repetition is gone.
    static let particles: [Color] = [particleAmber, particleDeep, particleGreen]
}

// MARK: - Bottom bloom (Figma 6396:9357) — the `classic` backdrop

/// Three concentric circles resting on the bottom edge: a gradient outer, a
/// gradient middle offset 8pt lower, and a solid core. Unlike the `refined`
/// aurora these do not grow — they idle, then leave.
///
/// Two motions, deliberately driven differently:
///
/// - **Drift** is continuous and never settles, so it comes from a
///   `TimelineView` rather than an animation. Nothing triggers it and nothing
///   ends it.
/// - **Exit** is a one-shot, so it rides plain animatable modifiers — `offset`
///   and `scaleEffect` — which SwiftUI interpolates when the parent's state
///   changes. Mixing the two lets each be expressed the way it actually
///   behaves instead of forcing both through one driver.
private struct BottomBloom: View {
    /// 0 small and sitting low, 1 settled at full size.
    var entrance: CGFloat
    /// 0 resting, 1 swollen to 1.96x and fully clear of the top edge.
    var exit: CGFloat
    /// When the drift clock started, so it is continuous across the sequence.
    var start: Date

    /// Ø, how far the centre sits ABOVE the bottom edge, and blur. Note the
    /// sign: the frame puts this bloom's centre 34pt inside the screen, where
    /// the old one was centred below it.
    private static let outer:  (d: CGFloat, rise: CGFloat, blur: CGFloat) = (388.0,     34.0, 22.71)
    private static let middle: (d: CGFloat, rise: CGFloat, blur: CGFloat) = (319.264,   26.0, 40.58)   // 8pt lower
    private static let core:   (d: CGFloat, rise: CGFloat, blur: CGFloat) = (174.0,     34.0, 40.58)

    /// How far below the Figma frame the whole body rests.
    private static let restDrop: CGFloat = 44

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let bloomScale: CGFloat = (0.45 + 0.55 * entrance) * (1 + 0.96 * exit)
            let bloomOffsetY: CGFloat = Self.restDrop + 90 * (1 - entrance)
                - (h + Self.outer.d) * exit
            let bloomOpacity: Double = Double(min(1, entrance * 1.4))

            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)

                ZStack {
                    circle(Self.outer, in: CGSize(width: w, height: h))
                        .fill(LinearGradient(
                            colors: [CoinsPalette.bloomOuterA, CoinsPalette.bloomOuterB],
                            startPoint: Self.spin(UnitPoint(x: 0, y: 0.5), by: sin(t * 0.62) * 0.9),
                            endPoint: Self.spin(UnitPoint(x: 0.946, y: 0.330), by: sin(t * 0.62) * 0.9)))
                        .blur(radius: Self.outer.blur)
                        .offset(x: CGFloat(sin(t * 0.31)) * 9,
                                y: CGFloat(cos(t * 0.24)) * 7)

                    circle(Self.middle, in: CGSize(width: w, height: h))
                        .fill(LinearGradient(
                            colors: [CoinsPalette.bloomMidA, CoinsPalette.bloomMidB],
                            startPoint: Self.spin(.leading, by: cos(t * 0.5 + 0.8) * 1.0),
                            endPoint: Self.spin(.trailing, by: cos(t * 0.5 + 0.8) * 1.0)))
                        .blur(radius: Self.middle.blur)
                        .offset(x: CGFloat(cos(t * 0.27)) * 12,
                                y: CGFloat(sin(t * 0.35)) * 8)

                    circle(Self.core, in: CGSize(width: w, height: h))
                        .fill(CoinsPalette.bloomCore)
                        .blur(radius: Self.core.blur)
                        .offset(x: CGFloat(sin(t * 0.4 + 1.2)) * 6,
                                y: CGFloat(cos(t * 0.33 + 0.5)) * 5)
                }
            }
            // Leaves as one body, so the three keep their relationship on the
            // way out. Overshoots the top by the outer circle's own diameter so
            // nothing is still clipping the edge when it stops.
            // Entrance and exit compose on the same two modifiers rather than
            // fighting over them: the bloom grows from 0.45 while rising the
            // last 90pt into place, then swells to 1.96x as it leaves. Anchored
            // to the bottom throughout so growing never lifts it off the edge.
            .scaleEffect(bloomScale, anchor: .bottom)
            .offset(y: bloomOffsetY)
            .opacity(bloomOpacity)
        }
        .allowsHitTesting(false)
    }

    /// Rotates a gradient endpoint about the unit square's centre, so the
    /// fill's axis keeps turning while the shape itself only drifts. Cheaper
    /// and steadier than moving the stops, and it never clips a colour out.
    private static func spin(_ p: UnitPoint, by angle: Double) -> UnitPoint {
        let dx = p.x - 0.5, dy = p.y - 0.5
        let c = CGFloat(cos(angle)), s = CGFloat(sin(angle))
        return UnitPoint(x: 0.5 + dx * c - dy * s, y: 0.5 + dx * s + dy * c)
    }

    private func circle(_ spec: (d: CGFloat, rise: CGFloat, blur: CGFloat),
                        in size: CGSize) -> some Shape {
        Circle()
            .path(in: CGRect(x: size.width / 2 - spec.d / 2,
                             y: size.height - spec.rise - spec.d / 2,
                             width: spec.d, height: spec.d))
    }
}

// MARK: - Coins backdrop: the field, and the aurora sweeping up it

/// The lilac→blush field with the aurora (Figma 4740:13077) swelling out of the
/// bottom edge behind a travelling wavefront of glass.
///
/// The aurora is four blurred discs — gold, lime, mint and a yellow core —
/// centred *below* the bottom edge, so only their upper halves and blur haloes
/// reach onto the page. In Figma they are exported as blurred `<circle>`
/// primitives; drawn natively here so they can grow (and so we avoid running
/// Figma SVGs through actool).
///
/// The mechanic is the header reveal from the companion `Homepage transition`
/// prototype turned upside down: there a disc grows out of the top edge and
/// swallows the header, here it grows out of the bottom edge and floods the
/// screen.
///
/// `Animatable` is what makes the coupling work. SwiftUI interpolates
/// `progress` itself and re-evaluates the body every frame, so the crest, the
/// disc growth and the fade all follow one real curve — instead of each
/// modifier animating independently between its own endpoints, which is all you
/// get from a plain animated `Bool`.
private struct AuroraBackdrop: View, Animatable {
    /// 0 → bare field, 1 → aurora across the whole screen.
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Fill, designed diameter, and how far the disc's CENTRE sits *below* the
    /// bottom edge — from the 390×840 Figma frame (centre Y − 840). Blur is the
    /// `stdDeviation` straight off the exported SVG filter, which is what
    /// SwiftUI's blur radius corresponds to.
    private static let discs: [(color: Color, size: CGFloat, drop: CGFloat, blur: CGFloat)] = [
        (CoinsPalette.gold,   604, 137.0, 35.35),   // 6277:9114
        (CoinsPalette.lime,   497, 149.5, 24.25),   // 6277:9122
        (CoinsPalette.mint,   327, 116.5, 24.25),   // 6277:9123
        (CoinsPalette.yellow, 163,  16.5, 24.25),   // 6277:9124
    ]

    /// The disc the others are sized against — the outermost, gold one.
    private static let baseRadius: CGFloat = 302
    private static let baseDrop: CGFloat = 137

    private func ramp(_ value: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        min(max((value - start) / (end - start), 0), 1)
    }

    // MARK: Curves — every sub-effect is a window onto the one driver

    /// The aurora fading up out of nothing, so it emerges rather than switching on.
    private var entry: CGFloat { ramp(progress, from: 0, to: 0.16) }

    // MARK: The beam that leads

    /// The beam runs out in front and the aurora follows it up: it finishes its
    /// climb at 62% of the sweep, well before the aurora lands. Squared so it
    /// leaves fast and decelerates into the top rather than arriving at a
    /// constant rate.
    private var beamRise: CGFloat {
        let t = ramp(progress, from: 0, to: 0.62)
        return 1 - (1 - t) * (1 - t)
    }

    /// Where the apex of the arc comes to rest. It parks on the balance pill, so
    /// the light it leaves behind is sitting under the coins as the particles
    /// gather.
    private static let beamRest: CGFloat = 120

    /// The arc is struck from the same centre as the orchid disc, below the
    /// bottom edge — that is what makes the beam curve along the aurora's own
    /// leading edge instead of cutting straight across the screen.
    private func beamCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height + Self.baseDrop)
    }

    /// Radius of that arc. At rest its apex sits at `beamRest` down the screen.
    private func beamRadius(in size: CGSize) -> CGFloat {
        let end = size.height + Self.baseDrop - Self.beamRest
        return Self.baseDrop + (end - Self.baseDrop) * beamRise
    }

    /// Half-width of the light band, in points.
    private static let beamBand: CGFloat = 170

    /// Strikes immediately, burns at full while travelling, then eases back to a
    /// steady glow once it has landed — which is what keeps it sitting at the top
    /// afterwards instead of going out when the sweep ends.
    private var beamIntensity: CGFloat {
        ramp(progress, from: 0, to: 0.06) * (1 - 0.30 * ramp(progress, from: 0.62, to: 0.82))
    }

    /// The lens only exists while the beam is travelling. Parked at the top it
    /// would sit there permanently distorting the pill, and it has to leave the
    /// tree rather than be disabled — see `AuroraBeamEffect`.
    private var isLensing: Bool { progress > 0.001 && beamRise < 0.999 }

    /// Eases the lens down before it is dropped, so nothing is cut mid-flight.
    private var lensExit: CGFloat { 1 - ramp(progress, from: 0.50, to: 0.62) }

    /// Where the halo reaches. Riding the crest (`refined`) it is a fixed radius
    /// around the band; anchored on the origin (`classic`) it grows with the
    /// sweep and runs ahead of the crest, as the header reveal does.
    private func bloomRadius(in size: CGSize) -> CGFloat {
        let variant = CoinsVariant.active
        return variant.beamHaloRadius > 0
            ? variant.beamHaloRadius
            : beamRadius(in: size) * 1.15 + 90
    }

    /// Strikes almost at once, burns while the beam travels, and is gone by the
    /// time it parks. It is centred on the ORIGIN at the bottom edge, so holding
    /// it past the landing would light the wrong end of the screen — the drawn
    /// band is what stays lit at the top.
    ///
    /// Far weaker than the 0.9 the header reveal uses, and deliberately so. That
    /// halo sits on a 340pt header where it reads as a hot spot at the contact
    /// point; here the sweep is full-screen and its radius reaches ~1000pt, so
    /// at 0.9 it floods everything below the crest — measured, it pushed the
    /// screen from 12% to 21% near-white and cut saturated colour from 34% to
    /// 25%, washing out the aurora the beam is supposed to be leading. The beam
    /// gets its strength from the crest terms instead, which stay on the band.
    private var bloomStrength: CGFloat {
        CoinsVariant.active.beamHaloStrength
            * ramp(progress, from: 0, to: 0.10)
            * (1 - ramp(progress, from: 0.46, to: 0.62))
    }

    // MARK: The aurora that follows

    /// How far past the top of the screen the aurora keeps climbing once it has
    /// covered it. Worth overshooting hard: the outermost orchid band is within
    /// a few points of the field's own lilac (#E89FE8 against #E5A5EA), so while
    /// it is the band sitting over the top half that half still reads as plain
    /// background. Driving it off the top is what carries the violet and the
    /// navy — the bands you can actually see — up the screen.
    /// How far up the screen the aurora itself has climbed. It lags the beam:
    /// the light arrives at the top at 62%, the aurora only at 100%.
    private func auroraReach(in size: CGSize) -> CGFloat {
        (size.height + CoinsVariant.active.auroraOvershoot) * progress
    }

    /// Disc growth is derived from that reach rather than run on its own
    /// schedule, so the top of the bloom always sits exactly where the aurora
    /// has climbed to. Solving `orchidTop == screenHeight - reach` for the scale
    /// gives this. At scale 1 the bloom is at its designed Figma size, which the
    /// sweep passes through on the way up rather than resting at.
    private func growth(in size: CGSize) -> CGFloat {
        max(0.12, (Self.baseDrop + auroraReach(in: size)) / Self.baseRadius)
    }

    var body: some View {
        // A GeometryReader rather than a passed-in screen size: an explicit
        // full-screen frame here would make this the tallest child of the
        // ZStack it sits in and drag every absolutely-positioned element on the
        // screen up with it. A GeometryReader takes the size it is offered.
        GeometryReader { geo in
            // The band straddles the aurora's edge, so it runs across the whole
            // backdrop rather than inside it — half the band lies over field the
            // aurora has not reached yet.
            if isLensing {
                field(in: geo.size)
                    .auroraBeam(center: beamCenter(in: geo.size),
                                radius: beamRadius(in: geo.size),
                                strength: lensExit,
                                bloomRadius: bloomRadius(in: geo.size),
                                bloomStrength: bloomStrength,
                                shading: CoinsVariant.active.beamShading,
                                haloAtCrest: CoinsVariant.active.beamHaloAtCrest)
            } else {
                field(in: geo.size)
            }
        }
        // Animatable above already drives every frame; let the descendants snap
        // to it rather than each starting an animation of its own.
        .transaction { $0.animation = nil }
        .allowsHitTesting(false)
    }

    /// The opaque backdrop the wave refracts: the page gradient with the aurora
    /// over it. It has to be opaque and full-bleed — the shader samples this
    /// layer, and sampling transparency punches holes wherever the crest bends
    /// outwards.
    private func field(in size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: CoinsPalette.fieldTop, location: 0),
                    .init(color: CoinsPalette.fieldMid, location: CoinsPalette.fieldMidStop),
                    .init(color: CoinsPalette.fieldBottom, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )

            let scale = growth(in: size)
            let blurScale = CoinsVariant.active.blurScalesLinearly ? scale : sqrt(scale)
            ForEach(Array(Self.discs.enumerated()), id: \.offset) { _, disc in
                Circle()
                    .fill(disc.color)
                    .frame(width: disc.size * scale, height: disc.size * scale)
                    // Blur grows with the disc, or a swollen one reads hard-edged
                    // — but only on the square root once the growth is large, or
                    // the falloff swallows the disc itself.
                    .blur(radius: disc.blur * blurScale)
                    .position(x: size.width / 2, y: size.height + disc.drop)
            }
            .opacity(Double(entry))

            beamLight(in: size)
        }
    }

    /// The light that leads the aurora up the screen: ONE curved band, struck
    /// from the same centre as the bloom discs so it arcs the way they do.
    ///
    /// Drawn as a `RadialGradient` whose stops travel outward rather than as a
    /// stroked ring: a stroke gives a hard-shouldered line that needs a second,
    /// wider stroke behind it to soften, and two strokes read as two lines. Moving
    /// the stops keeps it a single band with a symmetric falloff.
    ///
    /// The shader's own light would do this, but it is additive, and over a pale
    /// blush field an additive core clamps to white and stops reading. So the
    /// beam is drawn as a real element and composited normally — it has to
    /// separate from a near-white field at the start of its climb as well as from
    /// saturated violet at the end. The lens in `GlassWave.metal` sits on the same
    /// arc and supplies the refraction, so the two are one beam, not two.
    private func beamLight(in size: CGSize) -> some View {
        // Fixed outer radius so the stop positions are the only thing moving.
        let outer = size.height + Self.baseDrop + Self.beamBand
        let t = beamRadius(in: size) / outer
        let half = Self.beamBand / outer
        let clamp01: (CGFloat) -> CGFloat = { min(max($0, 0), 1) }
        let core = CoinsVariant.active.beamCoreOpacity

        return Rectangle()
            .fill(
                RadialGradient(
                    stops: [
                        // Lower than it looks it should be: the shader's crest
                        // now carries the light, and stacking flat white on top
                        // of it just buries the aurora's colour. This is the
                        // body of the beam; the shader supplies its intensity.
                        .init(color: .white.opacity(0), location: clamp01(t - half)),
                        .init(color: .white.opacity(core * 0.35), location: clamp01(t - half * 0.45)),
                        .init(color: .white.opacity(core), location: clamp01(t)),
                        .init(color: .white.opacity(core * 0.35), location: clamp01(t + half * 0.45)),
                        .init(color: .white.opacity(0), location: clamp01(t + half)),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: outer
                )
            )
            .frame(width: outer * 2, height: outer * 2)
            // Just enough to take the banding off the gradient's interpolation.
            .blur(radius: 14)
            .position(beamCenter(in: size))
            .opacity(Double(beamIntensity))
            .allowsHitTesting(false)
    }
}

// MARK: - Skew-and-lift exit

/// Shears the amount over while carrying it up and shrinking it, so it reads as
/// being drawn off the top of the screen rather than dissolving where it sits.
///
/// A `GeometryEffect` rather than `.transformEffect`: `CGAffineTransform` is not
/// animatable, so a plain transform would snap between endpoints. `GeometryEffect`
/// exposes `animatableData`, which lets SwiftUI interpolate the progress itself
/// and rebuild the matrix every frame.
private struct SkewLift: GeometryEffect {
    var progress: CGFloat

    /// Lean at full progress, as a shear factor.
    var shear: CGFloat = 0.5
    /// How much of its size it keeps.
    var endScale: CGFloat = 0.42
    /// How far it travels, in points.
    var lift: CGFloat = 260

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let s = 1 - (1 - endScale) * progress
        let k = shear * progress
        let cx = size.width / 2, cy = size.height / 2

        // Scale and shear about the centre, then carry the whole thing up.
        let m = CGAffineTransform(translationX: -cx, y: -cy)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(a: 1, b: 0, c: k, d: 1, tx: 0, ty: 0))
            .concatenating(CGAffineTransform(translationX: cx, y: cy - lift * progress))
        return ProjectionTransform(m)
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
    let aim: CGPoint         // where it heads, offset from the pill's centre
    let arc: CGFloat         // sideways bow along the path
    let loosenX: CGFloat     // outward fray as the cloud comes apart
    let loosenY: CGFloat     // continued climb through the fray
    let size: CGFloat
    let tint: Int            // index into the palette passed to the view
    let delay: Double
    let birthSpeed: CGFloat  // upward velocity inherited from the lifting number, pt/s
    let dur: Double
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
    /// How long the climb takes to reach terminal velocity, as a fraction of
    /// the flight, and the normaliser that keeps the curve landing on 1.
    private static let riseTau = 0.18
    /// Time constant for the sideways lean bleeding off, in seconds.
    private static let leanTau = 0.22
    private static let riseNorm = 1 - riseTau * (1 - exp(-1 / riseTau))

    let dots: [DissolveDot]
    let center: CGPoint
    let target: CGPoint
    let start: Date
    let palette: [Color]

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
                    if prog >= 1 { continue }          // arrived and gone
                    let sx = center.x + d.origin.x
                    let sy = center.y + d.origin.y
                    let gx = target.x + d.aim.x
                    let gy = target.y + d.aim.y

                    // Vertical plume. Each particle climbs in the column it was
                    // born in and only gathers toward the pill over the last
                    // third — lerping x at the target from birth (which is what
                    // this did before) collapses every column into a single
                    // converging fan, and the columns are the whole character
                    // of the effect.
                    // Buoyant rise. Something less dense than the fluid it is
                    // in accelerates until drag balances the buoyancy, then
                    // holds terminal velocity — it does not slow down on the
                    // way up. This is that solution, v = vt·(1 - e^(-t/τ)),
                    // integrated and normalised to land on 1: the climb is done
                    // accelerating inside the first fifth and runs straight
                    // after. The cubic ease-out it replaces did the opposite,
                    // which read as the particles being placed rather than
                    // rising.
                    // v(t) = vt + (v0 - vt)·e^(-t/τ), integrated and renormalised
                    // so the climb still lands exactly on the target whatever the
                    // particle was born doing. β is the inherited speed as a
                    // fraction of this particle's own terminal velocity — the
                    // one thing that decides whether it hangs at birth or
                    // carries on where the number left off.
                    //
                    // vTerm is estimated with the from-rest normaliser; feeding
                    // β back into it would be circular, and the error is second
                    // order at the βs the lift can produce (~0.2 at most).
                    let climb = sy - gy
                    let vTerm = climb / CGFloat(d.dur * Self.riseNorm)
                    let beta = vTerm > 1 ? Double(d.birthSpeed / vTerm) : 0
                    let k = (beta - 1) * Self.riseTau
                    let e = (prog + k * (1 - exp(-prog / Self.riseTau)))
                        / (1 + k * (1 - exp(-1 / Self.riseTau)))
                    // These three are keyed to HEIGHT, not to elapsed time.
                    // Under the old ease-out the two were nearly the same
                    // thing, so `prog` stood in for both; under a constant-
                    // velocity climb they diverge hard — the old prog 0.52 fade
                    // now falls at 43% of the way up rather than 89%, which
                    // would vanish the cloud before it got anywhere near the
                    // pill. Stated as heights they also survive the next change
                    // to the velocity curve.
                    let gather = max(0, (e - 0.80) / 0.20)
                    // The cloud comes apart at the end: rather than being drawn
                    // tight into the pill, each particle keeps most of its own
                    // heading, frays outward and thins away, so the arrival
                    // reads as a dispersal rather than everything funnelling
                    // into one point.
                    let loosen = max(0, (e - 0.72) / 0.28)
                    let fray = loosen * loosen
                    let gatherEase = gather * gather * (3 - 2 * gather) * 0.35
                    // Lateral drag. Buoyancy keeps feeding the climb, but
                    // nothing sustains the sideways lean, so it decays and the
                    // displacement saturates early — the columns splay as they
                    // leave the glyphs and then straighten. `arc * e` grew the
                    // lean all the way to the pill, which kept them fanning for
                    // the whole flight.
                    //
                    // Off `life`, not `prog`: drag decays on a physical
                    // timescale, so a slow particle should not get a
                    // proportionally slower decay just because its flight is
                    // longer. The cost is that the very quickest particles
                    // reach ~90% of their lean rather than all of it.
                    let column = sx + d.arc * CGFloat(1 - exp(-life / Self.leanTau))
                    let x = column + (gx - column) * gatherEase + d.loosenX * fray
                    let y = sy + (gy - sy) * e + d.loosenY * fray
                    let bornOp = min(life / 0.1, 1)    // quick fade-in at birth
                    // Everything fades out on the way in — nothing is left
                    // orbiting the pill once the cloud has passed.
                    let arriveFade = e < 0.68 ? 1.0 : max(0, 1 - (e - 0.68) / 0.32)
                    let op = bornOp * arriveFade
                    let r = d.size * (1 - 0.2 * prog - 0.35 * fray)
                    if op <= 0.02 { continue }
                    let rect = CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)
                    let base = palette[d.tint % palette.count]
                    ctx.fill(Path(ellipseIn: rect), with: .color(base.opacity(op)))
                }
            }
        }
    }
}

// MARK: - Ripple text (per-character wave: scale + light-yellow flash, L→R)

/// Lays the string out one character at a time; when `trigger` changes, a
/// ripple travels left to right — each character pops up in scale and flashes
/// a light yellow as the wave passes through it.
private struct RippleText: View {
    let text: String
    let font: Font
    let base: Color
    let trigger: Int

    private let stagger = 0.045          // wave speed: delay per character

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                RippleChar(ch: String(ch), font: font, base: base,
                           // Never 0: a zero-duration hold keyframe degenerates
                           // and blanks the glyph.
                           delay: 0.02 + Double(i) * stagger, trigger: trigger)
            }
        }
    }
}

private struct RippleCharState {
    var scale: CGFloat = 1
    var tint: Double = 0                 // 0 = base color, 1 = ripple yellow
}

private struct RippleChar: View {
    let ch: String
    let font: Font
    let base: Color
    let delay: Double
    let trigger: Int

    private let rippleYellow = Color(red: 1.0, green: 0.87, blue: 0.40)  // light yellow

    /// iOS 16 fallback state — see `keyframed` for the real thing.
    @State private var popped = false

    @ViewBuilder
    var body: some View {
        if #available(iOS 17.0, *) {
            keyframed
        } else {
            // No keyframe animator on iOS 16. The per-character delay still
            // produces the travelling wave; it just runs as one spring rather
            // than a scripted pop-and-settle.
            Text(ch)
                .font(font)
                .foregroundColor(base)
                .overlay(
                    Text(ch)
                        .font(font)
                        .foregroundColor(rippleYellow)
                        .opacity(popped ? 1 : 0)
                )
                .scaleEffect(popped ? 1.32 : 1.0, anchor: .bottom)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: popped)
                .onValueChange(of: trigger) { value in
                    guard value > 0 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        popped = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            popped = false
                        }
                    }
                }
        }
    }

    @available(iOS 17.0, *)
    private var keyframed: some View {
        Text(ch)
            .font(font)
            .foregroundColor(base)
            .keyframeAnimator(initialValue: RippleCharState(), trigger: trigger) { view, s in
                view
                    // Yellow copy of the glyph crossfades over the base color.
                    .overlay(
                        Text(ch)
                            .font(font)
                            .foregroundColor(rippleYellow)
                            .opacity(s.tint)
                    )
                    .scaleEffect(s.scale, anchor: .bottom)
            } keyframes: { _ in
                // The per-character delay is a hold segment, so one shared
                // trigger produces a left-to-right travelling wave.
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1.0, duration: delay)
                    CubicKeyframe(1.32, duration: 0.16)
                    SpringKeyframe(1.0, duration: 0.42,
                                   spring: .init(response: 0.3, dampingRatio: 0.55))
                }
                KeyframeTrack(\.tint) {
                    LinearKeyframe(0.0, duration: delay)
                    LinearKeyframe(1.0, duration: 0.14)
                    LinearKeyframe(0.0, duration: 0.42)
                }
            }
    }
}

// MARK: - Pressable button style (scale-down + haptic on touch)

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            // Purely a press effect: snap down fast on touch, recover quickly
            // on release so the button is back at full size before anything
            // else (like the page transition) happens.
            .animation(configuration.isPressed
                       ? .easeOut(duration: 0.08)
                       : .spring(response: 0.2, dampingFraction: 0.8),
                       value: configuration.isPressed)
            .onValueChange(of: configuration.isPressed) { pressed in
                if pressed { Haptics.light() }
            }
    }
}

// MARK: - Animated confetti burst

/// One confetti piece: launched from the bottom edge with an upward velocity,
/// it decelerates under gravity, flutters sideways, tumbles, and fades as it
/// falls back out of the screen.
private struct ConfettiPiece {
    enum Kind: CaseIterable { case rect, circle, streamer, triangle }
    let x0: CGFloat          // launch x as a fraction of the width
    let vx: CGFloat          // horizontal drift (pt/s)
    let vy: CGFloat          // upward launch velocity (pt/s)
    let delay: Double
    let color: Color
    let size: CGFloat
    let kind: Kind
    let rot0: Double         // initial rotation
    let spin: Double         // rad/s
    let swayAmp: CGFloat     // flutter amplitude
    let swayFreq: Double
    let phase: Double
}

/// Draws the burst each frame via a `Canvas` — same pattern as the coins
/// particle dissolve, so ~100 pieces animate smoothly.
private struct ConfettiBurstView: View {
    let start: Date
    private let pieces: [ConfettiPiece] = Self.make()

    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.30, blue: 0.43),   // pink red
        Color(red: 1.00, green: 0.48, blue: 0.27),   // coral
        Color(red: 1.00, green: 0.66, blue: 0.25),   // orange
        Color(red: 0.98, green: 0.86, blue: 0.08),   // yellow
        Color(red: 0.45, green: 0.83, blue: 0.24),   // lime
        Color(red: 0.37, green: 0.87, blue: 0.65),   // mint
        Color(red: 0.25, green: 0.77, blue: 1.00),   // cyan
        Color(red: 0.35, green: 0.49, blue: 0.97),   // blue
        Color(red: 0.57, green: 0.33, blue: 0.87),   // purple
        Color(red: 0.97, green: 0.35, blue: 0.67),   // magenta
    ]

    private static func make(count: Int = 110) -> [ConfettiPiece] {
        (0..<count).map { _ in
            ConfettiPiece(
                x0: .random(in: 0.02...0.98),
                vx: .random(in: -70...70),
                vy: .random(in: 420...880),      // rises ~100…450pt before falling
                delay: .random(in: 0...0.55),
                color: palette.randomElement()!,
                size: .random(in: 6...11),
                kind: ConfettiPiece.Kind.allCases.randomElement()!,
                rot0: .random(in: 0 ..< (2 * .pi)),
                spin: .random(in: -7 ... 7),
                swayAmp: .random(in: 6...22),
                swayFreq: .random(in: 2.2...4.6),
                phase: .random(in: 0 ..< (2 * .pi))
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                guard t < 3.2 else { return }        // one ~3s burst, then done
                let g: CGFloat = 820                 // gravity, pt/s²
                for p in pieces {
                    let life = t - p.delay
                    guard life > 0 else { continue }
                    let x = p.x0 * size.width + p.vx * life
                        + p.swayAmp * CGFloat(sin(life * p.swayFreq + p.phase))
                    let y = size.height + 12 - p.vy * life + 0.5 * g * life * life
                    guard y < size.height + 24 else { continue }   // fallen out
                    // Quick fade-in at birth; fade away late in the fall.
                    let op = min(life / 0.08, 1)
                        * (life > 2.0 ? max(0, 1 - (life - 2.0) / 0.7) : 1)
                    if op <= 0.02 { continue }

                    var c = ctx
                    c.opacity = op
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.rot0 + p.spin * life))
                    // Tumble: squash across one axis so flat pieces look 3D.
                    let squash = 0.35 + 0.65 * abs(cos(life * p.swayFreq * 1.3 + p.phase))
                    let s = p.size
                    let path: Path
                    switch p.kind {
                    case .rect:
                        path = Path(CGRect(x: -s / 2 * squash, y: -s / 2,
                                           width: s * squash, height: s))
                    case .circle:
                        path = Path(ellipseIn: CGRect(x: -s / 2, y: -s / 2 * squash,
                                                      width: s, height: s * squash))
                    case .streamer:
                        path = Path(roundedRect: CGRect(x: -s * 0.17, y: -s * 0.65,
                                                        width: s * 0.34, height: s * 1.3),
                                    cornerRadius: s * 0.17)
                    case .triangle:
                        var tri = Path()
                        tri.move(to: CGPoint(x: 0, y: -s / 2))
                        tri.addLine(to: CGPoint(x: s / 2 * squash, y: s / 2))
                        tri.addLine(to: CGPoint(x: -s / 2 * squash, y: s / 2))
                        tri.closeSubpath()
                        path = tri
                    }
                    c.fill(path, with: .color(p.color))
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

    /// iOS 16 fallback state — see `keyframed` for the real thing.
    @State private var landed = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            keyframed(content)
        } else {
            // No keyframe animator and no distortion shader on iOS 16, so the
            // card still flies up and rotates into place but without the bow
            // through the middle or the overshoot past its resting position.
            content
                .scaleEffect(landed ? 1 : 0.2, anchor: .bottom)
                .rotation3DEffect(.degrees(landed ? 0 : -45), axis: (x: 1, y: 0, z: 0),
                                  anchor: .bottom, perspective: 1.0)
                .offset(y: landed ? 0 : 600)
                .opacity(landed ? 1 : 0)
                .onValueChange(of: trigger) { value in
                    guard value > 0 else { return }
                    withAnimation(.spring(response: 0.75, dampingFraction: 0.78)) {
                        landed = true
                    }
                }
        }
    }

    @available(iOS 17.0, *)
    private func keyframed(_ content: Content) -> some View {
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
