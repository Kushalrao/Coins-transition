//
//  RewardStackView.swift
//  Vacations
//
//  Reward-card stack. The view itself is animation-agnostic: it owns the
//  drag state, gesture, snap, and rendering loop, but defers per-card
//  position/scale/opacity to a `CardStackAnimation` value. Each animation
//  is a self-contained struct that defines how a single card moves through
//  its life — peek → emerge → exit. New animations are added by
//  conforming a new struct to `CardStackAnimation` and passing it in.
//

import SwiftUI

// MARK: - Animation interface

/// Defines how cards move through the stack. The view owns the gesture and
/// drag bookkeeping; a `CardStackAnimation` owns the per-card visual.
///
/// Coordinate system: `cp` (card progress) is a single card's progress along
/// its own path.
///   cp =  0  → card is at the front slot (the focal point)
///   cp <  0  → card is queued behind, awaiting its turn at the front
///   cp >  0  → card has passed the front and is on its way out
/// The view renders cards whose cp falls inside `[-2 - entryFadeRange,
/// exitFadeRange)`; everything else is culled.
protocol CardStackAnimation {
    /// Drag distance in pt that advances the stack by one card.
    var dragPerCard: CGFloat { get }
    /// How far past cp = 0 a card stays rendered before being culled.
    var exitFadeRange: CGFloat { get }
    /// How far behind cp = -2 a card stays rendered before being culled.
    var entryFadeRange: CGFloat { get }

    /// Returns the slot (size/opacity/corner-radius/etc.) and an extra
    /// y-offset to apply on top of `slot.yOffset`. The view positions the
    /// card at `centerY + slot.yOffset + extraY`.
    func slot(forCardProgress cp: CGFloat) -> (slot: StackSlot, extraY: CGFloat)
}

// MARK: - Animation 1 — J-curve with springy hook

/// iPhone lock-screen style notification stack. Each card traces a J:
///   • Peek phase (curve): card walks the back→middle→front keyframes,
///     scaling and fading up to 1.0.
///   • Linear phase (long stroke): once at the front, further drag
///     translates the card linearly upward off-screen.
///   • Springy hook at the bottom of the J — the descent dips past the
///     natural back-peek, then springs upward to settle `bottomLift` pt
///     above the back-peek position. The spring rate is tuned to outrun
///     the natural descent so the trajectory is monotonic — no jerk back
///     down at the settle point.
struct JCurveAnimation: CardStackAnimation {
    var dragPerCard: CGFloat = 180
    var exitFadeRange: CGFloat = 2.5
    var entryFadeRange: CGFloat = 1.0

    /// Vertical translation per unit of card-progress past the front. Roughly
    /// one card-row, so exiting cards stack upward as they leave.
    var linearStep: CGFloat = 220
    /// Final upward offset at the settled back position.
    var bottomLift: CGFloat = 42
    /// Depth of the dip past the natural back-peek before the spring back.
    var bottomOvershoot: CGFloat = 14
    /// What fraction of the descent (cp ∈ [-1, -2]) is the down-phase before
    /// the spring kicks in. Larger = deeper dip, snappier rebound.
    var downPhaseEnd: CGFloat = 0.65

    func slot(forCardProgress cp: CGFloat) -> (slot: StackSlot, extraY: CGFloat) {
        if cp >= 0 {
            // Linear stroke. Front shape, translating up by cp·linearStep.
            return (.front, -cp * linearStep)
        }
        if cp >= -1 {
            // Curve, near-front segment: middle → front.
            let t = cp + 1
            return (StackSlot.interpolate(from: .middle, to: .front, t: t), liftAt(cp))
        }
        if cp >= -2 {
            // Curve, far-back segment: back → middle.
            let t = cp + 2
            return (StackSlot.interpolate(from: .back, to: .middle, t: t), liftAt(cp))
        }
        // Beyond the back peek: hold at back position (with the same upward
        // lift as cp = -2 so there's no y-discontinuity at the boundary) and
        // fade out so deeper cards don't pop in abruptly when scrolled toward.
        let fade = max(0, 1 + (cp + 2) / entryFadeRange)
        return (StackSlot.back.withOpacity(StackSlot.back.opacity * Double(fade)), liftAt(cp))
    }

    /// Springy hook at the bottom of the J. Smoothstep down-phase (descent
    /// and natural fall pull together so smoothing is fine), linear
    /// spring-back (constant rate beats the natural descent → monotonic up
    /// to the settle point, no jerk).
    private func liftAt(_ cp: CGFloat) -> CGFloat {
        guard cp <= -1 else { return 0 }
        let t = min(1, -(cp + 1))   // 0 at cp = -1, 1 at cp = -2, clamps beyond
        if t < downPhaseEnd {
            let s = t / downPhaseEnd
            let smooth = s * s * (3 - 2 * s)
            return bottomOvershoot * smooth
        } else {
            let s = (t - downPhaseEnd) / (1 - downPhaseEnd)
            return bottomOvershoot + (-bottomLift - bottomOvershoot) * s
        }
    }
}

// MARK: - View

struct RewardStackView: View {
    let animation: any CardStackAnimation
    /// Pure passthrough. Forwarded to each `RewardCardView` so the card
    /// header swaps from gift-wrap to a destination photo. Doesn't touch
    /// the scroll/animation logic in this view.
    var isUnlocked: Bool = false

    @State private var cards: [RewardCardModel] = RewardCardModel.demo
    @State private var dragOffset: CGFloat = 0
    @State private var dragBase: CGFloat = 0

    /// Rubber-band stiffness when dragging past the deck's first/last card.
    /// Lower = more give; 1.0 = no rubber-band. Owned by the view, not the
    /// animation, since the deck-end behavior is the same regardless of how
    /// individual cards move.
    private let edgeResistance: CGFloat = 0.3

    init(animation: any CardStackAnimation = JCurveAnimation(),
         isUnlocked: Bool = false) {
        self.animation = animation
        self.isUnlocked = isUnlocked
    }

    var body: some View {
        GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2

            ZStack {
                ForEach(visibleEntries(), id: \.index) { entry in
                    RewardCardView(model: entry.card,
                                   slot: entry.slot,
                                   isUnlocked: isUnlocked)
                        .position(x: centerX, y: centerY + entry.yOffset)
                        .zIndex(entry.zIndex)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(scrollGesture)
        }
    }

    // MARK: - Progress

    /// Total advancement through the stack, in units of cards. 0 = initial
    /// state (card 0 at front). 1 = card 1 at front. Etc.
    private var globalProgress: CGFloat {
        -dragOffset / animation.dragPerCard
    }

    /// Last card cannot be advanced past the front. First card cannot retreat
    /// below initial state.
    private var maxProgress: CGFloat {
        max(0, CGFloat(cards.count - 1))
    }

    // MARK: - Entries

    private struct Entry {
        let index: Int
        let card: RewardCardModel
        let slot: StackSlot
        let yOffset: CGFloat
        let zIndex: Double
    }

    private func visibleEntries() -> [Entry] {
        cards.indices.compactMap { i in
            let cp = globalProgress - CGFloat(i)
            guard cp > -2 - animation.entryFadeRange,
                  cp < animation.exitFadeRange else { return nil }
            let (slot, extraY) = animation.slot(forCardProgress: cp)
            return Entry(
                index: i,
                card: cards[i],
                slot: slot,
                yOffset: slot.yOffset + extraY,
                // Most-recently-fronted cards stay on top of the cards still
                // queued behind them — matches lock-screen notifications where
                // the latest card overlays the older ones as they slide away.
                zIndex: Double(cp)
            )
        }
    }

    // MARK: - Gesture

    private var scrollGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let proposed = dragBase + value.translation.height
                dragOffset = rubberBanded(proposed)
                logCardStates()
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height - value.translation.height
                // Project a portion of the fling, then snap to the nearest
                // whole-card position so the stack rests with one card cleanly
                // at the front.
                let projected = dragOffset + velocity * 0.18
                let lowerBound = -maxProgress * animation.dragPerCard
                let clamped = max(lowerBound, min(0, projected))
                let snappedProgress = (-clamped / animation.dragPerCard).rounded()
                let target = -snappedProgress * animation.dragPerCard
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 16)) {
                    dragOffset = target
                }
                dragBase = target
            }
    }

    /// Apply rubber-band resistance once the drag passes either deck end. The
    /// further past the end, the more the next pt of finger travel is damped,
    /// so the cards visibly slow as you keep pulling — and snap back on release.
    private func rubberBanded(_ raw: CGFloat) -> CGFloat {
        let lowerBound = -maxProgress * animation.dragPerCard
        if raw > 0 {
            return raw * edgeResistance
        }
        if raw < lowerBound {
            return lowerBound + (raw - lowerBound) * edgeResistance
        }
        return raw
    }

    // MARK: - Logging

    private func logCardStates() {
        func r(_ v: CGFloat, _ p: Int = 2) -> String {
            let m = pow(10.0, Double(p))
            return String(Double((v * CGFloat(m)).rounded()) / m)
        }
        var line = "drag=\(r(dragOffset, 1)) gp=\(r(globalProgress, 3))"
        for entry in visibleEntries() {
            let cp = globalProgress - CGFloat(entry.index)
            let scale = entry.slot.width / StackSlot.front.width
            line += " | i=\(entry.index) cp=\(r(cp, 2)) y=\(r(entry.yOffset, 1)) scale=\(r(scale, 3)) opacity=\(r(CGFloat(entry.slot.opacity), 2))"
        }
        print(line)
    }
}

// MARK: - StackSlot helpers

private extension StackSlot {
    func withOpacity(_ newOpacity: Double) -> StackSlot {
        StackSlot(
            width: width,
            height: height,
            yOffset: yOffset,
            opacity: newOpacity,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            shadowSpread: shadowSpread
        )
    }
}
