//
//  TripAnnouncementView.swift
//  Vacations
//
//  Animation 2 — announcement screen + tap-to-expand into detail view.
//  Source: Figma file TYBKT7Qs2E6zdT6h2BuFWZ, nodes 1361:9828 (announcement)
//  and 1054:17994 (detail). All numeric values, fonts, colors, and layout
//  are lifted verbatim from those frames.
//
//  Architecture: a SINGLE always-mounted layout. The orange→yellow gradient
//  trip card stays in the tree across both states; its frame, corner
//  radius, and position morph based on `showDetail`. Inside the card, the
//  announcement-state inner content (white experience card + View trip
//  button) and the detail-state inner content (stacked photos, flag,
//  trip-title pill, intent options, Continue) swap via `.transition`.
//
//  This is critical: when the parent stays mounted, the inner conditional
//  views' .transition modifiers actually fire. Earlier versions used a
//  top-level if-else between separate views, which made the parent itself
//  the thing being inserted/removed and silently overrode the inner
//  transitions.
//

import SwiftUI

struct TripAnnouncementView: View {
    /// Figma reference frame width. The design is laid out for a 390-wide
    /// iPhone. Internal positions are absolute against this reference.
    private let referenceWidth: CGFloat = 390

    // MARK: - Entrance animation state

    /// Trigger for the keyframe-animated entrance. Bumped 0 → 1 once after
    /// a brief delay so SwiftUI commits the initial state before the
    /// keyframes start playing.
    @State private var animationTrigger: Int = 0
    /// The two heading texts fade in late so the card is the focal point.
    @State private var headingsPresented: Bool = false
    /// The "You just earned" footer pill fades in after the card has landed.
    @State private var earnedPresented: Bool = false
    /// Number of balance characters revealed so far — drives the ticker that
    /// feeds the balance in one number at a time.
    @State private var revealedDigits: Int = 0
    /// One-time, super-subtle "lean toward the coins" gesture: the trip card
    /// dips down a touch and tilts back at the bottom once the coins appear.
    @State private var coinNudgeY: CGFloat = 0
    @State private var coinTilt: Double = 0
    /// Subtle continuous idle while the coins show — the card wanders a little
    /// and stretches slightly. Two desynced oscillators (0…1, different
    /// periods) give an organic "here and there" feel. Reset when the sheet
    /// rises.
    @State private var idleA: CGFloat = 0
    @State private var idleB: CGFloat = 0

    /// Balance shown in the footer pill, fed in character-by-character.
    private let earnedBalance = "5,790"
    private var earnedBalanceChars: [String] { earnedBalance.map(String.init) }

    // MARK: - Tap / detail-screen state

    /// Which screen is currently presented. The trip card stays mounted
    /// across all three states; only its frame, position, corner radius,
    /// and inner content change. `.announcement` is the initial small card,
    /// `.detail` is the expanded "Your trip name / Munich in" layout, and
    /// `.rewards` reuses the discount-card stack from animation 1.
    @State private var screen: Screen = .announcement
    private var isExpanded: Bool { screen != .announcement }

    enum Screen { case announcement, detail, rewards }
    /// Brief tap-down state on the trip card. Scales the whole card to
    /// `cardPressScale` for a beat, then springs back as the morph begins.
    @State private var cardPressDown: Bool = false
    private let cardPressScale: CGFloat = 0.94
    /// User-editable trip title shown inside the glass pill on the detail
    /// layout. Newline character separates the two visible lines.
    @State private var tripTitle: String = "Munich in Summers, 2026"
    @FocusState private var tripTitleFocused: Bool
    /// Drives the slide-to-unlock control on the rewards screen. Pure
    /// passthrough into `RewardStackView` — when true, each card swaps its
    /// gift-wrap art for the destination photograph.
    @State private var rewardsUnlocked: Bool = false
    /// Live drag progress (0 → 1) reported by the slide-to-unlock control.
    /// During a drag the reward stack translates downward proportionally;
    /// on commit the slider resets this to 0, so the stack springs back up
    /// — synchronised with the moment the unlocked images take over.
    @State private var unlockSwipeProgress: CGFloat = 0
    /// Maximum downward translation the reward stack travels while the user
    /// is dragging the slider.
    private let unlockScrollAmount: CGFloat = 90

    // MARK: - Card sizes (Figma)

    private let announcementCardWidth: CGFloat = 300
    private let announcementCardHeight: CGFloat = 419
    private let detailCardWidth: CGFloat = 358
    private let detailCardHeight: CGFloat = 714
    private let announcementCornerRadius: CGFloat = 24
    private let detailCornerRadius: CGFloat = 40

    // MARK: - Reward sheet state (Figma nodes 2615:1940 + 2620:2283)

    /// Drives the bottom "Your rewards" sheet rising and the trip card
    /// shrinking up to make room for it.
    @State private var rewardSheetPresented: Bool = false
    /// Bumped when the sheet rises to play the shrink keyframe timeline
    /// (warp + top-led 3D tilt + scale dip), mirroring the entrance. Keyframe
    /// values animate; an externally-driven value would be swallowed by the
    /// keyframeAnimator and the warp wouldn't sweep.
    @State private var shrinkTrigger: Int = 0
    /// Shader-bow amount during the shrink. Animated with withAnimation and
    /// applied OUTSIDE the keyframeAnimators (on the already-framed card), so
    /// the distortion has valid geometry and the value actually sweeps.
    @State private var shrinkWarp: CGFloat = 0

    // MARK: - Coin-drop into the sheet

    /// Coins streamed from the "You just earned" pill into the sheet's
    /// coins-balance card as the sheet rises.
    @State private var dropCoinsOpacity: [Double] = Array(repeating: 0, count: 9)
    @State private var dropCoinsArrived: [Bool] = Array(repeating: false, count: 9)
    /// The earned pill lifts up and fades as it sheds its coins.
    @State private var footerLift: CGFloat = 0
    @State private var footerFaded: Bool = false
    /// The offer-card Rive gift fills the whole card initially, then collapses
    /// to its icon (revealing the offer text) after ~3s.
    @State private var giftExpanded: Bool = true
    /// Gift centre — x and y animate with separate springs so the collapse
    /// follows a curved, springy path instead of a straight diagonal.
    @State private var giftX: CGFloat = 171 / 2
    @State private var giftY: CGFloat = 175 / 2
    /// Sheet coins balance is revealed digit-by-digit (same ticker cascade as
    /// the earned pill) as the dropped coins land.
    @State private var sheetRevealedDigits: Int = 0
    private let sheetBalanceFinal = "16,500"
    private var sheetBalanceChars: [String] { sheetBalanceFinal.map(String.init) }

    /// Per-coin spawn offsets (around the earned pill) and sizes.
    private let dropCoinSpread: [(dx: CGFloat, dy: CGFloat, size: CGFloat)] = [
        (-44, 4, 26), (-22, -8, 22), (0, 6, 30), (22, -6, 22), (44, 4, 26),
        (-32, 10, 24), (12, -12, 20), (34, 12, 24), (-10, -4, 28),
    ]

    /// Shrunk "Trip card" dimensions — Figma node 2620:2283.
    private let shrunkCardWidth: CGFloat = 232
    private let shrunkCardHeight: CGFloat = 307
    private let shrunkCornerRadius: CGFloat = 22.558
    /// Height of the bottom reward sheet — sized to contain the content
    /// (title + cards ≈ 235) with ~31 pt bottom padding above the home
    /// indicator plus the bottom safe-area inset. Figma node 2615:1940.
    private let rewardSheetHeight: CGFloat = 300

    /// True while the announcement card is shrunk under the reward sheet.
    private var isShrunk: Bool { rewardSheetPresented && !isExpanded }

    /// Card geometry, accounting for the tap-expand (detail) and the
    /// reward-sheet shrink.
    private var cardWidth: CGFloat {
        if isExpanded { return detailCardWidth }
        return isShrunk ? shrunkCardWidth : announcementCardWidth
    }
    private var cardHeight: CGFloat {
        if isExpanded { return detailCardHeight }
        return isShrunk ? shrunkCardHeight : announcementCardHeight
    }
    private var cardCornerRadius: CGFloat {
        if isExpanded { return detailCornerRadius }
        return isShrunk ? shrunkCornerRadius : announcementCornerRadius
    }

    var body: some View {
        GeometryReader { proxy in
            let centerX = max(proxy.size.width, referenceWidth) / 2
            let detailCenterY = proxy.size.height / 2 + 5
            // Announcement card sits at the true vertical centre of the screen.
            let announcementCenterY = proxy.size.height / 2
            // When shrunk, the card sits centred in the space above the sheet,
            // nudged up a little.
            let shrunkCenterY = (160 + (proxy.size.height - rewardSheetHeight + 34)) / 2 - 28
            // Coin-stream endpoints: from the earned pill down to the sheet's
            // coins-balance card (its SpinCoin badge).
            let dropCoinOrigin = CGPoint(x: centerX, y: 645)
            let dropCoinDest = CGPoint(x: centerX - 143, y: proxy.size.height - 210)

            ZStack(alignment: .topLeading) {
                // Background. Starts as today's solid cream; once the rewards
                // sheet rises, it warms into the Figma gradient (#F7F9F4 →
                // #FBE8C2, node 2615:1910). The gradient fades in over the
                // solid, animating with the sheet.
                ZStack {
                    (isExpanded ? DesignColors.detailBackground : DesignColors.background)
                    LinearGradient(
                        colors: [DesignColors.sheetBgTop, DesignColors.sheetBgBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(isShrunk ? 1 : 0)
                }
                .ignoresSafeArea()

                // Subheading + main heading — Figma nodes 1361:9840/9837.
                // 8 pt between the two; hidden when the detail view is shown.
                VStack(spacing: 8) {
                    Text("London, England")
                        .font(DesignFont.medium(16))
                        .foregroundColor(DesignColors.alertYellow600)

                    Text("Your flight is successfully booked")
                        .font(DesignFont.semibold(24))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineSpacing(30 - 24 * 1.2)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 328)
                }
                .opacity(headingsPresented && !isExpanded ? 1 : 0)
                .position(x: centerX, y: 72)

                // Trip card — single always-mounted view whose frame and
                // position morph based on `showDetail`. The keyframeAnimator
                // wraps the card so the entrance animation runs once on
                // appear; once settled (trigger = 1) the modifiers are
                // identity, and the showDetail-driven morph layers on top.
                tripCardContainer(centerX: centerX, announcementCenterY: announcementCenterY, shrunkCenterY: shrunkCenterY, detailCenterY: detailCenterY)
                    .scaleEffect(x: 1 + idleA * 0.022, y: 1 + idleB * 0.022, anchor: .center)
                    .rotation3DEffect(.degrees(coinTilt), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 1.0)
                    .offset(x: idleA * 6 - idleB * 3, y: coinNudgeY + idleB * 5 - idleA * 2)

                // "You just earned" footer — Figma node 2624:1355. Fades in
                // after the card has landed; hidden once the card expands.
                earnedFooter
                    .opacity(earnedPresented && !isExpanded && !footerFaded ? 1 : 0)
                    .offset(y: (earnedPresented ? 0 : 12) + footerLift)
                    .position(x: centerX, y: 660 + 84 / 2)

                // Reward sheet — Figma node 2615:1940. Slides up from the
                // bottom; the trip card shrinks above it.
                rewardSheet
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: rewardSheetPresented ? 0 : rewardSheetHeight + 140)
                    .ignoresSafeArea(edges: .bottom)

                // Coins streamed from the earned pill into the sheet's coins
                // card as the sheet rises. Drawn above the sheet so they stay
                // visible flying over it, then fade as they land.
                ForEach(0..<dropCoinSpread.count, id: \.self) { i in
                    let sp = dropCoinSpread[i]
                    Image("SpinCoinBadge")
                        .resizable().interpolation(.high)
                        .frame(width: sp.size, height: sp.size)
                        .opacity(dropCoinsOpacity[i])
                        .position(
                            x: dropCoinsArrived[i] ? dropCoinDest.x : dropCoinOrigin.x + sp.dx,
                            y: dropCoinsArrived[i] ? dropCoinDest.y : dropCoinOrigin.y + sp.dy
                        )
                }

                // Tap-anywhere-outside-the-card to dismiss the detail view.
                if isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
                                // Step back one screen rather than fully
                                // dismissing — rewards → detail → announcement.
                                switch screen {
                                case .rewards: screen = .detail
                                case .detail: screen = .announcement
                                case .announcement: break
                                }
                            }
                        }
                        .zIndex(-1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task {
                guard animationTrigger == 0 else { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
                animationTrigger = 1

                // Start the gentle idle (wander + stretch) right away so the
                // card keeps moving continuously from the entrance onward —
                // no static beat before the coins drift begins.
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { idleA = 1 }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { idleB = 1 }

                // Headings fade in 0.4s before the card animation completes.
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeOut(duration: 0.4)) {
                    headingsPresented = true
                }

                // "You just earned" footer follows after the card has landed.
                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    earnedPresented = true
                }

                // As the coins appear and ticker in, the trip card leans toward
                // them: a slow, continuous downward drift with its bottom edge
                // warping back. Both resolve when the sheet rises.
                // The idle is already running; now ease in the slow downward
                // drift + bottom back-warp so it blends with the ongoing motion.
                withAnimation(.easeInOut(duration: 2.5)) { coinNudgeY = 14 }
                withAnimation(.easeInOut(duration: 1.4)) { coinTilt = -3 }

                // Ticker the balance in. The stagger (50 ms) is shorter than
                // each digit's spring (~0.32 s), so digits start one after the
                // other but their animations overlap — a quick parallel cascade
                // rather than fully one-at-a-time.
                try? await Task.sleep(nanoseconds: 260_000_000)
                for _ in earnedBalanceChars.indices {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        revealedDigits += 1
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }

                // After ~2s on this screen, raise the rewards sheet and shrink
                // the trip card up. The shrink keyframe timeline (warp + tilt +
                // scale dip) plays alongside the resize for a fluid morph.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                shrinkTrigger += 1
                withAnimation(.easeInOut(duration: 0.42)) {
                    shrinkWarp = 0.18
                }
                withAnimation(.spring(response: 0.9, dampingFraction: 0.92)) {
                    rewardSheetPresented = true
                    coinNudgeY = 0
                    coinTilt = 0
                    idleA = 0
                    idleB = 0
                }
                // Reset the warp after its brief pulse (independent timing).
                Task {
                    try? await Task.sleep(nanoseconds: 420_000_000)
                    withAnimation(.easeOut(duration: 0.5)) { shrinkWarp = 0 }
                }

                // The offer gift shows full-card for ~3s, then collapses to its
                // icon and reveals the offer text.
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    // Curved, springy collapse: size + y settle quickly while x
                    // trails with a little overshoot, so the gift arcs up-then-
                    // left into the corner instead of sliding in a straight line.
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                        giftExpanded = false
                    }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        giftY = 36
                    }
                    withAnimation(.spring(response: 1.15, dampingFraction: 0.6).delay(0.18)) {
                        giftX = 36
                    }
                }

                // Lift the earned pill and stream its coins into the sheet's
                // coins-balance card, one after another. Each coin emerges from
                // the pill, flies UP staying opaque, then fades only once it
                // reaches the card — so it reads as landing in, not vanishing
                // mid-air.
                try? await Task.sleep(nanoseconds: 80_000_000)
                withAnimation(.easeOut(duration: 0.3)) { footerLift = -55 }
                for i in 0..<dropCoinSpread.count {
                    withAnimation(.easeOut(duration: 0.14)) {
                        dropCoinsOpacity[i] = 1            // emerge from the pill
                    }
                    let idx = i
                    Task {
                        try? await Task.sleep(nanoseconds: 90_000_000)
                        // fly up into the card, staying fully opaque
                        withAnimation(.easeInOut(duration: 0.52)) {
                            dropCoinsArrived[idx] = true
                        }
                        // land: quick fade as it drops into the card
                        try? await Task.sleep(nanoseconds: 450_000_000)
                        withAnimation(.easeOut(duration: 0.16)) {
                            dropCoinsOpacity[idx] = 0
                        }
                    }
                    // tight stagger so all coins leave while the pill is still
                    // above the rising sheet (not popping in over its middle).
                    try? await Task.sleep(nanoseconds: 35_000_000)
                }

                // Fade the emptied pill away.
                try? await Task.sleep(nanoseconds: 260_000_000)
                withAnimation(.easeOut(duration: 0.4)) { footerFaded = true }

                // Ticker the new balance in digit-by-digit as the coins land —
                // same overlapping cascade as the earned pill.
                for _ in sheetBalanceChars.indices {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        sheetRevealedDigits += 1
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }
    }

    // MARK: - Trip card container

    /// The whole trip card. Stays in the view tree in both states; only its
    /// frame, position, corner radius, and inner content change. Inner
    /// content swaps with `.transition(.move(edge: .leading) + .opacity)`,
    /// so on tap the announcement copy slides off to the left and the
    /// detail content slides in from the left at the same time.
    @ViewBuilder
    private func tripCardContainer(centerX: CGFloat, announcementCenterY: CGFloat, shrunkCenterY: CGFloat, detailCenterY: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Gradient backdrop. RoundedRectangle's cornerRadius is
            // animatable, so toggling between 24 and 40 inside withAnimation
            // smoothly interpolates the rounding as the card resizes.
            RoundedRectangle(
                cornerRadius: cardCornerRadius,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [DesignColors.tripCardGradientTop,
                             DesignColors.tripCardGradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Conditional inner content. Because the parent ZStack stays
            // mounted, these views are inserted/removed individually within
            // a stable parent — and their .transition modifiers fire.
            switch screen {
            case .announcement:
                if isShrunk {
                    bookingCardContent
                        .transition(.opacity)
                } else {
                    // Plain cross-fade (no leading slide) so the photo doesn't
                    // shoot to the left when the card shrinks into the booking
                    // layout.
                    announcementInnerContent
                        .transition(.opacity)
                }
            case .detail:
                detailContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .rewards:
                rewardsContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Persistent "View Booking" button — bottom-anchored so it tracks
            // the card's bottom edge and rides the shrink with the card,
            // instead of its label popping from "View trip" to "View Booking".
            if screen == .announcement {
                tripCardButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .scaleEffect(cardPressDown ? cardPressScale : 1.0)
        .keyframeAnimator(
            initialValue: TripCardAnimState(),
            trigger: animationTrigger,
            content: { content, state in
                // distortionEffect rasterises its child into a Metal layer.
                // Inside that layer, interactive content like TextField
                // can't receive input and SwiftUI replaces it with a
                // prohibited-input glyph. So apply the shader only while
                // the entrance is actually warping; once warp settles to 0
                // we hand the live (non-rasterised) view back so editable
                // controls work normally.
                // Rasterise (and warp) for the WHOLE announcement state, not
                // just while warp > 0. Toggling the distortionEffect on/off as
                // the warp crosses zero swaps between two different AnyView
                // identities, which makes the card blink. Detail/rewards stay
                // un-rasterised so their TextField still receives input.
                let rendered = (state.warp > 0.001)
                    ? AnyView(content.distortionEffect(
                        ShaderLibrary.cardWarp(
                            .float2(announcementCardWidth, announcementCardHeight),
                            .float(state.warp)
                        ),
                        maxSampleOffset: CGSize(width: 32, height: 0)
                    ))
                    : AnyView(content)
                rendered
                    .scaleEffect(state.scale, anchor: .bottom)
                    .rotation3DEffect(
                        .degrees(state.rotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 1.0
                    )
                    .offset(y: state.offsetY)
                    .opacity(state.opacity)
            },
            keyframes: { _ in
                KeyframeTrack(\.offsetY) {
                    CubicKeyframe(-30, duration: 0.55)
                    CubicKeyframe(0,   duration: 0.45)
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
                    CubicKeyframe(0,   duration: 0.45)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.3)
                }
            }
        )
        // Shrink timeline — plays when the sheet rises. The bottom-anchored
        // cardWarp shader bows the TOP sideways while the bottom stays planted;
        // a bottom-anchored 3D tilt sends the top edge back first; a scale dip
        // adds the squeeze. All keyframe-driven, so the warp actually sweeps.
        .keyframeAnimator(
            initialValue: ShrinkAnimState(),
            trigger: shrinkTrigger,
            content: { content, s in
                // Transforms only — these render fine inside the animator. The
                // shader bow is applied outside (see CardBowEffect below).
                content
                    .scaleEffect(s.scale, anchor: .bottom)
                    .rotation3DEffect(
                        .degrees(s.rotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 1.0
                    )
            },
            keyframes: { _ in
                KeyframeTrack(\.rotation) {
                    CubicKeyframe(4, duration: 0.42)
                    CubicKeyframe(0, duration: 0.55)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.95, duration: 0.42)
                    CubicKeyframe(1.0, duration: 0.55)
                }
            }
        )
        // Frame is applied OUTSIDE the keyframeAnimator so the size/corner
        // morph runs on a normal animation transaction — the keyframeAnimator
        // swallows implicit animations of its content's layout. The card is
        // still proposed this size top-down, so the warp shader rasterises at
        // the correct dimensions during the entrance.
        .frame(width: cardWidth, height: cardHeight)
        .animation(.spring(response: 0.9, dampingFraction: 0.92), value: rewardSheetPresented)
        // Shader bow applied OUTSIDE the keyframeAnimators, on the already-
        // framed (sized) card. Inside the animators the distortion had no valid
        // geometry — it rendered no bow and vanished when over-driven. Out here
        // it renders, and shrinkWarp (withAnimation) sweeps + is tunable.
        .modifier(CardBowEffect(
            active: screen == .announcement,
            width: announcementCardWidth,
            height: announcementCardHeight,
            amount: shrinkWarp
        ))
        .shadow(color: .black.opacity(0.12),
                radius: (64 + 8) / 2,
                x: 0, y: 0)
        .position(
            x: centerX,
            y: isExpanded ? detailCenterY : (isShrunk ? shrunkCenterY : announcementCenterY)
        )
    }

    // MARK: - Announcement inner content (white card + button)

    /// Both pieces are pinned via `.position` inside the 300×419 card frame.
    /// During the morph to detail, the parent ZStack frame grows; these
    /// children carry their own `.transition` (set on the conditional in
    /// `tripCardContainer`) so they slide off to the leading edge while
    /// fading.
    private var announcementInnerContent: some View {
        ZStack(alignment: .topLeading) {
            innerWhiteCard
                .frame(width: 276, height: 320)
                .position(x: announcementCardWidth / 2, y: 12 + 320 / 2)
            // Button lives outside this content — it's a persistent element
            // (see tripCardButton) so it doesn't cross-fade during the shrink.
        }
        // Lay the content out in a fixed-size canvas and centre that canvas in
        // the (animating) card frame, so it never drifts horizontally as the
        // card resizes during the shrink.
        .frame(width: announcementCardWidth, height: announcementCardHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// White card holding the experience photo, the Experience/date row,
    /// and the title. 276 × 320, rounded 16. Figma node 1361:9847.
    private var innerWhiteCard: some View {
        ZStack(alignment: .topLeading) {
            DesignColors.cardSurface

            // Image — Figma node 1361:9848.
            Image("NYCTimesSquare")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 260, height: 212)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .position(x: 276 / 2, y: 8 + 212 / 2)

            // Experience row — Figma node 1361:9852.
            experienceRow
                .frame(height: 20)
                .position(x: 16 + experienceRowWidth / 2,
                          y: 236 + 20 / 2)

            // Title — Figma node 1361:9857.
            Text("NYC: See Yourself on a Times Square Billboard")
                .font(DesignFont.medium(14))
                .foregroundColor(.black)
                .tracking(-0.168)
                .lineSpacing(20 - 14 * 1.2)
                .frame(width: 244, height: 40, alignment: .topLeading)
                .multilineTextAlignment(.leading)
                .position(x: 16 + 244 / 2, y: 260 + 40 / 2)
        }
        .frame(width: 276, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private let experienceRowWidth: CGFloat = 160

    private var experienceRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                // Scapia icon font glyph U+1012F4 — placeholder render via
                // system font; swap to the icon font when added.
                Text("\u{1012F4}")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignColors.primaryScapia400)

                Text("Experience")
                    .font(DesignFont.medium(14))
                    .foregroundColor(DesignColors.primaryScapia400)
            }

            Text("24 Mar")
                .font(DesignFont.medium(14))
                .foregroundColor(DesignColors.textBlack56)
        }
        .lineLimit(1)
    }

    private let buttonHeight: CGFloat = 24 + 12 * 2  // line height 24 + py 12

    private var viewTripButton: some View {
        Button {
            // Phase 1 (~140ms): card scales down for tactile press feedback.
            withAnimation(.easeOut(duration: 0.14)) {
                cardPressDown = true
            }
            // Phase 2: release press and trigger morph in the same spring
            // so the card springs back up as it grows into the detail layout.
            Task {
                try? await Task.sleep(nanoseconds: 140_000_000)
                withAnimation(.spring(response: 0.9, dampingFraction: 0.78)) {
                    cardPressDown = false
                    screen = .detail
                }
            }
        } label: {
            Text("View trip")
                .font(DesignFont.medium(16))
                .foregroundColor(DesignColors.textHighEmphasis)
                .frame(height: 24)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(DesignColors.cardSurface))
        }
        .buttonStyle(.plain)
    }

    // MARK: - "You just earned" footer (Figma node 2624:1355)

    /// Label + white coin-balance pill shown at the bottom of the
    /// announcement page. 349 × 84 in Figma: the "You just earned" label sits
    /// on top, then an 8 pt gap, then a 145 × 52 white capsule holding the
    /// SpinCoin badge and the balance in SemiBold 24.
    private var earnedFooter: some View {
        VStack(spacing: 8) {
            Text("You just earned")
                .font(DesignFont.regular(16))
                .foregroundColor(DesignColors.alertYellow700)
                .frame(height: 24)

            HStack(spacing: 8) {
                Image("SpinCoinBadge")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)
                HStack(spacing: 0) {
                    ForEach(Array(earnedBalanceChars.enumerated()), id: \.offset) { i, ch in
                        Text(ch)
                            .font(DesignFont.semibold(24))
                            .foregroundColor(Color(red: 20 / 255, green: 28 / 255, blue: 32 / 255))
                            .tracking(0.96)
                            .opacity(revealedDigits > i ? 1 : 0)
                            .offset(y: revealedDigits > i ? 0 : 10)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(width: 145, height: 52)
            .background(Capsule().fill(Color.white))
        }
    }

    // MARK: - Shrunk booking card (Figma node 2620:2283)

    /// Content shown when the card shrinks under the reward sheet: a white
    /// booking card (destination photo + date + name) with a "View Booking"
    /// button.
    private var bookingCardContent: some View {
        ZStack(alignment: .topLeading) {
            bookingInnerCard
                .frame(width: 223.4, height: 226.77)
                .position(x: shrunkCardWidth / 2, y: 4.28 + 226.77 / 2)
            // Button is the shared persistent tripCardButton (below).
        }
        // Fixed canvas, centred in the card — keeps the content from drifting
        // horizontally while the card resizes.
        .frame(width: shrunkCardWidth, height: shrunkCardHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var bookingInnerCard: some View {
        ZStack(alignment: .topLeading) {
            // Same image as the announcement card so the photo stays
            // continuous through the shrink — reads as one fluid morph.
            Image("NYCTimesSquare")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 223.4, height: 226.77)
                .clipped()

            // "14 Jun" date pill — top-left.
            Text("14 Jun")
                .font(DesignFont.medium(14))
                .foregroundColor(Color.black.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white))
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
                .fixedSize()
                .position(x: 12.72 + 35, y: 12.72 + 18)

            // Destination "Paris" over the photo.
            Text("Paris")
                .font(DesignFont.extraBold(32))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.44), radius: 12, x: 0, y: 4)
                .frame(width: 200, alignment: .leading)
                .position(x: 16 + 100, y: 190)
        }
        .frame(width: 223.4, height: 226.77)
        .clipShape(RoundedRectangle(cornerRadius: 19.04, style: .continuous))
    }

    private var bookingButton: some View {
        Text("View Booking")
            .font(DesignFont.medium(15))
            .foregroundColor(DesignColors.textHighEmphasis)
            .padding(.horizontal, 18.8)
            .padding(.vertical, 11.3)
            .background(Capsule().fill(Color.white))
    }

    /// Persistent card button shown across both the announcement and the
    /// shrunk booking layouts. Anchored to the card's bottom edge so it rides
    /// the shrink as one continuous element — its label never changes.
    private var tripCardButton: some View {
        Text("View Booking")
            .font(DesignFont.medium(16))
            .foregroundColor(DesignColors.textHighEmphasis)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.white))
    }

    // MARK: - Reward sheet (Figma node 2615:1940)

    private var rewardSheet: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DesignColors.alertYellow500)
                Text("Your rewards")
                    .font(DesignFont.medium(16))
                    .foregroundColor(.black)
            }
            .padding(.top, 16)

            HStack(spacing: 16) {
                coinsRewardCard
                discountRewardCard
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: rewardSheetHeight)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 20, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 20,
                style: .continuous
            )
            .fill(Color.white)
            .shadow(color: .black.opacity(0.08), radius: 40, x: 0, y: -4)
        )
    }

    private var coinsRewardCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)

            Image("SpinCoinBadge")
                .resizable().interpolation(.high)
                .frame(width: 48, height: 48)
                .position(x: 36, y: 36)

            Text("COINS BALANCE")
                .font(DesignFont.regular(10)).tracking(1)
                .foregroundColor(Color(red: 0x55 / 255, green: 0x5E / 255, blue: 0x66 / 255).opacity(0.8))
                .frame(width: 147, alignment: .leading)
                .position(x: 12 + 147 / 2, y: 72 + 8)

            HStack(spacing: 0) {
                ForEach(Array(sheetBalanceChars.enumerated()), id: \.offset) { i, ch in
                    Text(ch)
                        .font(DesignFont.semibold(24))
                        .foregroundColor(.black)
                        .opacity(sheetRevealedDigits > i ? 1 : 0)
                        .offset(y: sheetRevealedDigits > i ? 0 : 10)
                }
            }
            .frame(width: 147, alignment: .leading)
            .position(x: 12 + 147 / 2, y: 90 + 14)

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 12))
                Text("Instantly credited").font(DesignFont.regular(14))
            }
            .foregroundColor(DesignColors.alertYellow500)
            .frame(width: 147, alignment: .leading)
            .position(x: 12 + 147 / 2, y: 139 + 10)
        }
        .frame(width: 171, height: 175)
        // Drop shadow (Figma): x0 y0, blur 80 (≈ radius 40), spread 12, #000 6%.
        .shadow(color: .black.opacity(0.06), radius: 40, x: 0, y: 0)
    }

    private var discountRewardCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)

            // Offer text — revealed once the gift collapses to its icon.
            Group {
                Text("For Stays in Paris")
                    .font(DesignFont.regular(13))
                    .foregroundColor(Color.black.opacity(0.8))
                    .frame(width: 147, alignment: .leading)
                    .position(x: 12 + 147 / 2, y: 72 + 9)

                Text("Get ₹2,500 Off")
                    .font(DesignFont.medium(16))
                    .foregroundColor(DesignColors.textHighEmphasis)
                    .frame(width: 147, alignment: .leading)
                    .position(x: 12 + 147 / 2, y: 91 + 12)

                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 12))
                    Text("Valid for 2 days").font(DesignFont.regular(14))
                }
                .foregroundColor(DesignColors.alertYellow500)
                .frame(width: 147, alignment: .leading)
                .position(x: 12 + 147 / 2, y: 139 + 10)
            }
            .opacity(giftExpanded ? 0 : 1)

            // Rive gift (GiftAnimation.riv) — fills the whole offer card
            // initially, then shrinks to the top-left icon as the text reveals.
            RiveGiftView()
                .frame(width: giftExpanded ? 171 : 64,
                       height: giftExpanded ? 175 : 64)
                .position(x: giftX, y: giftY)
        }
        .frame(width: 171, height: 175)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        // Drop shadow (Figma): x0 y0, blur 80 (≈ radius 40), spread 12, #000 6%.
        .shadow(color: .black.opacity(0.06), radius: 40, x: 0, y: 0)
    }

    // MARK: - Detail inner content (Figma node 1054:17994)

    /// All foreground content for the detail layout. Lives inside the
    /// 358×714 trip card. Wrapped in a single ViewBuilder so a single
    /// `.transition` slides the whole group in from the leading edge while
    /// the gradient backdrop morphs underneath.
    @ViewBuilder
    private var detailContent: some View {
        // Back photo card — Figma node 1054:18007.
        // 209 × 289.333, rotated -2°, border 2px white@40, rounded 30,
        // shadow 0 0 64 8 white@32, image opacity 50%.
        stackedPhotoCard(
            width: 209,
            height: 289.333,
            rotation: -2,
            imageOpacity: 0.5,
            center: CGPoint(x: 180.42, y: 171.6)
        )

        // Front photo card — Figma node 1054:18008.
        // 209 × 274.266, rotated +2°, border 2px white@40, rounded 30,
        // shadow 0 0 64 8 white@32, image full opacity.
        stackedPhotoCard(
            width: 209,
            height: 274.266,
            rotation: 2,
            imageOpacity: 1.0,
            center: CGPoint(x: 190.11, y: 174.1)
        )

        // Flag badge — Figma node 1054:18009.
        // 62 × 60, top 275, centered, white border 4px, rounded 12.
        Image("GermanyFlag")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 62, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 4)
            )
            .position(x: detailCardWidth / 2, y: 275 + 60 / 2)

        // "Your trip name" — Figma node 1054:18010.
        // top 367, centered, Lexend Deca Medium 16 / line 24, color #FFFBE6.
        Text("Your trip name")
            .font(DesignFont.medium(16))
            .foregroundColor(DesignColors.alertYellow000)
            .frame(height: 24)
            .position(x: detailCardWidth / 2, y: 367 + 24 / 2)

        // Glass pill with trip title — Figma node 1054:18044.
        // 334 × 94, top 403, centered, bg white@16%, rounded 20.
        tripTitlePill
            .frame(width: 334, height: 94)
            .position(x: detailCardWidth / 2, y: 403 + 94 / 2)

        // Three intent icons — Figma nodes 1054:18011/12/13 + labels 14/15/16.
        // Icon glyphs at top 521 (44pt SF Compact Rounded private-use chars
        // — substituted with SF Symbols + circle). Labels at top 578.
        intentOption(
            symbol: "briefcase.fill",
            label: "For work",
            isSelected: false,
            centerX: detailCardWidth / 2 - 97.5
        )
        intentOption(
            symbol: "house.fill",
            label: "Going Home",
            isSelected: false,
            centerX: detailCardWidth / 2
        )
        intentOption(
            symbol: "sailboat.fill",
            label: "Vacationing",
            isSelected: true,
            centerX: detailCardWidth / 2 + 95.5
        )

        // Continue button — Figma node 1056:18051.
        // top 642, centered, white bg, rounded 30. Padding pl 24 / pr 12,
        // py 12, gap 8. "Continue" Lexend Deca Medium 16 / 24, color
        // #262B30. Arrow icon 24×24 right side.
        continueButton
            .position(x: detailCardWidth / 2, y: 642 + (24 + 12 * 2) / 2)
    }

    /// One of the two stacked photo cards at the top of the detail layout.
    @ViewBuilder
    private func stackedPhotoCard(
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        imageOpacity: Double,
        center: CGPoint
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        Image("NYCTimesSquare")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipShape(shape)
            .opacity(imageOpacity)
            .overlay(shape.strokeBorder(Color.white.opacity(0.4), lineWidth: 2))
            .shadow(color: Color.white.opacity(0.32),
                    radius: (64 + 8) / 2, x: 0, y: 0)
            .rotationEffect(.degrees(rotation))
            .position(x: center.x, y: center.y)
    }

    private var tripTitlePill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.16))
                // Tapping anywhere on the pill focuses the field — bigger
                // target than just the text glyphs.
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onTapGesture { tripTitleFocused = true }

            // Trip title — Figma node 1054:18006.
            // Lexend Deca Bold 28, color white@88%, centered. Editable:
            // axis-vertical TextField wraps the text based on the pill's
            // width. The initial value is a single line without a literal
            // `\n` — Lexend Deca has no glyph for the newline character
            // and renders it as a missing-glyph "🚫" otherwise.
            TextField("Trip name", text: $tripTitle, axis: .vertical)
                .focused($tripTitleFocused)
                .font(DesignFont.bold(28))
                .foregroundColor(Color.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .tint(Color.white)
                .padding(.horizontal, 12)
        }
    }

    /// Round icon + label below it. Position is the icon's horizontal center;
    /// the icon sits at Figma top 521, the label at top 578.
    @ViewBuilder
    private func intentOption(
        symbol: String,
        label: String,
        isSelected: Bool,
        centerX: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white, lineWidth: 1.5)
            Image(systemName: symbol)
                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.white)
        }
        .frame(width: 44, height: 44)
        .position(x: centerX, y: 521 + 44 / 2)

        Text(label)
            .font(isSelected ? DesignFont.semibold(12) : DesignFont.medium(12))
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.8))
            .position(x: centerX, y: 578 + 14 / 2)
    }

    private var continueButton: some View {
        Button {
            // Continue advances to the rewards screen — same animation
            // recipe as the View trip → detail morph.
            withAnimation(.spring(response: 0.9, dampingFraction: 0.78)) {
                screen = .rewards
            }
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(DesignFont.medium(16))
                    .foregroundColor(DesignColors.textHighEmphasis)
                    .frame(height: 24)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignColors.textHighEmphasis)
                    .frame(width: 24, height: 24)
            }
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Rewards inner content (Figma node 1056:18067)

    /// Rewards screen reached by tapping Continue from the detail layout.
    /// Reuses the discount-card stack component (`RewardStackView`) we
    /// built for animation 1, with its J-curve scrolling interaction.
    /// Lives inside the same 358×714 trip card frame; the gradient
    /// backdrop shared with the detail screen acts as this screen's bg.
    @ViewBuilder
    private var rewardsContent: some View {
        // "scapia / Rewards" lockup — Figma node 1056:18106.
        // Container: 85×40, top 24, centered. Logo is 63.059×16; "Rewards"
        // wordmark sits below at 21.333pt.
        rewardsLogoStack
            .frame(width: 85, height: 40)
            .position(x: detailCardWidth / 2, y: 24 + 40 / 2)

        // Heading — Figma node 1056:18105.
        // top 84, width 326, Lexend Deca Bold 28, color white@88%, centered,
        // wraps to 3 visible lines at this width.
        Text("Unlock vacation rewards up to Rs45,000")
            .font(DesignFont.bold(28))
            .foregroundColor(Color.white.opacity(0.88))
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 326, alignment: .top)
            .position(x: detailCardWidth / 2, y: 84 + 60)

        // Discount card stack — reuse the existing `RewardStackView`. Its
        // GeometryReader-based layout centers cards around the proxy's
        // centre, so positioning the wrapper frame at y = 422 inside the
        // 714-tall card lines the front card up at y = 408.5 — matching
        // Figma's 50% + 51.5px coordinate. `isUnlocked` is a pure
        // passthrough — no scroll/animation logic in the stack changes.
        //
        // Live offset based on `unlockSwipeProgress`: while the user drags
        // the slide-to-unlock thumb, the stack translates downward. On
        // commit the slider resets the progress back to 0 with a spring,
        // so the stack snaps upward — at exactly the moment `isUnlocked`
        // flips and the cards swap to their destination photos. Reads as
        // "press the deck down, release, deck springs up showing the
        // unlocked imagery."
        RewardStackView(isUnlocked: rewardsUnlocked)
            .frame(width: detailCardWidth, height: 500)
            .offset(y: unlockSwipeProgress * unlockScrollAmount)
            .position(x: detailCardWidth / 2, y: 422)

        // Slide-to-unlock control. Placed near the bottom of the trip card,
        // 24pt inside its left/right edges. Once the deck is unlocked the
        // control fades away — the swipe-to-unlock affordance is no longer
        // needed and removing it lets the unlocked photos breathe.
        if !rewardsUnlocked {
            SlideToUnlockButton(
                isUnlocked: $rewardsUnlocked,
                dragProgress: $unlockSwipeProgress
            )
            .frame(width: detailCardWidth - 48, height: 56)
            .position(x: detailCardWidth / 2,
                      y: detailCardHeight - 24 - 56 / 2)
            .transition(.opacity)
        }
    }

    /// Vertical "scapia / Rewards" lockup. The logo asset is the scapia
    /// wordmark SVG; "Rewards" is rendered in a system serif at 21.333pt
    /// (Figma's Test Domaine Display isn't bundled, so we approximate).
    private var rewardsLogoStack: some View {
        VStack(spacing: 0) {
            Image("ScapiaLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 63.059, height: 16)

            Text("Rewards")
                .font(.system(size: 21.333, weight: .semibold, design: .serif))
                .foregroundColor(DesignColors.rewardsTextCream)
                .tracking(-0.512)
                .shadow(color: Color.white.opacity(0.25),
                        radius: 2.667, x: 0, y: 2.667)
        }
    }
}

#Preview {
    TripAnnouncementView()
}

// MARK: - Animation state

/// Animatable state for the trip-card warp-in. Each property is driven by
/// its own KeyframeTrack inside the keyframeAnimator, so timing and curves
/// can be tuned independently per-property.
private struct TripCardAnimState {
    var offsetY: CGFloat = 600   // starts fully below the screen
    var scale: CGFloat = 0.2     // starts tiny, grows in two phases
    var rotation: Double = -45   // top edge tilted forward toward viewer
    var warp: CGFloat = 1        // shader bow at full strength
    var opacity: Double = 0
}

/// Animatable state for the shrink: a horizontal warp (cardWarp shader), a
/// top-led 3D tilt, and a scale dip — all bottom-anchored so the top edge
/// leads and the lower part follows as the card scales down.
private struct ShrinkAnimState {
    var rotation: Double = 0
    var scale: CGFloat = 1
}

/// Applies the cardWarp shader bow to the already-sized card. Gated by
/// `active` (announcement only) so the detail/rewards states keep live,
/// un-rasterised content (their TextField needs input). Living outside the
/// keyframeAnimators, it has valid geometry and `amount` animates normally.
private struct CardBowEffect: ViewModifier {
    let active: Bool
    let width: CGFloat
    let height: CGFloat
    let amount: CGFloat

    func body(content: Content) -> some View {
        if active {
            content.distortionEffect(
                ShaderLibrary.cardWarp(.float2(width, height), .float(amount)),
                maxSampleOffset: CGSize(width: 32, height: 0)
            )
        } else {
            content
        }
    }
}
