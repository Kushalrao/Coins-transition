//
//  RewardStackView.swift
//  Vacations
//
//  Three reward cards stacked the way iPhone lock-screen notifications stack.
//  The user scrolls vertically anywhere on the page; cards drift slowly with
//  the finger (a fraction of the drag distance), the front card stays at full
//  opacity, and on release the spring animation either commits to the next /
//  previous step or snaps back. The list is finite — there is no wrap-around;
//  scrolling past the first or last card meets rubber-band resistance.
//

import SwiftUI

struct RewardStackView: View {
    @State private var cards: [RewardCardModel] = RewardCardModel.demo
    @State private var topIndex: Int = 0
    /// Cumulative scroll position. Negative = scrolled up (cards expanded
    /// into a list). Spring-snaps to one of the two stable states on
    /// release; the chosen state then persists so the next drag continues
    /// from there.
    @State private var dragOffset: CGFloat = 0
    /// `dragOffset` snapshot for the currently-settled state (collapsed or
    /// expanded). New drags start from here.
    @State private var dragBase: CGFloat = 0
    @State private var isCommitting: Bool = false

    /// Two stable states — compact stack and fully-expanded list.
    private let collapsedOffset: CGFloat = 0
    private var expandedOffset: CGFloat { -dragRange }

    /// How much of the finger's vertical travel the front card translates
    /// vertically. Small enough to feel slow at typical drag distances;
    /// total movement is unbounded so a long drag carries the card a long way.
    private let frontYFollow: CGFloat = 0.15

    /// Drag distance that drives one full step of the visual transition.
    /// Larger than the commit threshold on purpose: a typical swipe only
    /// nudges the cards a fraction of the way (≈ 15–20 pt at 90 pt drag),
    /// matching the "slow-moving" feel; the spring on release finishes the
    /// journey to the next / previous step.
    private let dragRange: CGFloat = 500
    /// Drag (or velocity) past which a release commits.
    private let commitThreshold: CGFloat = 50
    private let velocityThreshold: CGFloat = 600

    var body: some View {
        GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2

            ZStack {
                ForEach(visibleEntries(), id: \.rel) { entry in
                    RewardCardView(model: entry.card, slot: entry.slot)
                        .position(
                            x: centerX,
                            y: centerY + entry.slot.yOffset
                                + (entry.rel == 0 ? frontYOffset : stackScrollOffset)
                        )
                        .zIndex(entry.zIndex)
                }
            }
            // Page-level gesture surface — capture scrolls anywhere on the
            // stack's region, not just on the front card.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(scrollGesture)
        }
    }

    // MARK: - Entries

    private struct Entry {
        let rel: Int
        let card: RewardCardModel
        let slot: StackSlot
        let zIndex: Double
    }

    /// Bounded — no modulo wrap. At the first card there is nothing above;
    /// at the last card there is nothing below. All cards in the data set
    /// are rendered so they can fan into the expanded list.
    private func visibleEntries() -> [Entry] {
        let count = cards.count
        let rels = Array(-1..<count)
        return rels.compactMap { rel in
            let idx = topIndex + rel
            guard idx >= 0, idx < count else { return nil }
            let card = cards[idx]
            let slot = slot(forRelativeIndex: rel, progress: visualProgress)
            let z: Double = rel == -1
                ? (visualProgress < 0 ? Double(count + 2) : -1)
                : Double(count - rel)
            return Entry(rel: rel, card: card, slot: slot, zIndex: z)
        }
    }

    // MARK: - Slot computation

    /// Signed normalized progress derived from the drag. Clamped to [−1, +1]
    /// at the boundaries via `clampDragForBoundary` so the visual transition
    /// can't overshoot either end of the list.
    private var visualProgress: CGFloat {
        -dragOffset / dragRange
    }

    /// Vertical offset applied to the front card on top of its slot's
    /// resting yOffset. Slow follow of the finger drag — the front card
    /// drifts as the user scrolls, stays at full opacity, never scales.
    private var frontYOffset: CGFloat {
        dragOffset * frontYFollow
    }

    /// Vertical offset applied to every non-front card *only* past the slot
    /// transition (|dragOffset| > dragRange). Once the back card has fully
    /// arrived at slot 0, further dragging translates the whole stack at
    /// the same slow rate — no scaling, no opacity change, just movement.
    private var stackScrollOffset: CGFloat {
        if dragOffset < -dragRange {
            return (dragOffset + dragRange) * frontYFollow
        }
        if dragOffset > dragRange {
            return (dragOffset - dragRange) * frontYFollow
        }
        return 0
    }

    private func slot(forRelativeIndex rel: Int, progress p: CGFloat) -> StackSlot {
        let cp = max(-1, min(1, p))
        if cp >= 0 {
            // Advancing (scroll up). Each card has a **two-phase** path
            // that's strictly sequenced with its neighbours:
            //
            //   Phase A (emerge):  compactSlot → .front  (card comes
            //                       forward into the active position)
            //   Phase B (move up): .front → listSlot     (card slides up
            //                       out of the way for the next one)
            //
            // Card N's "move up" runs in parallel with card N+1's "emerge",
            // so at any given time only those two cards are moving — the
            // rest are static. As the user keeps scrolling the cascade
            // continues: each card emerges, then moves up to make room.
            return advanceSlot(for: rel, progress: cp)
        } else {
            // Retreating — collapse back toward the compact stack.
            let t = -cp
            switch rel {
            case -1: return StackSlot.interpolate(from: aboveTopRestSlot, to: .front,  t: t)
            case 0:  return .front
            case 1:  return StackSlot.interpolate(from: .middle,          to: .back,   t: t)
            default: return restingSlot(forRelativeIndex: rel)
            }
        }
    }

    /// Two-phase advance: emerge to the front, then move up to the list.
    /// Each phase takes one "slot" of overall progress, sized so the whole
    /// cascade fits in 0…1 for the current card count.
    private func advanceSlot(for rel: Int, progress p: CGFloat) -> StackSlot {
        let phaseDuration: CGFloat = 1.0 / CGFloat(cards.count)
        // Emerge runs from (rel−1)·phase → rel·phase.
        // Move up runs from rel·phase → (rel+1)·phase.
        // Front card has no emerge — it starts already at the front.
        let emergeStart  = CGFloat(max(rel - 1, 0)) * phaseDuration
        let emergeEnd    = CGFloat(rel) * phaseDuration
        let moveUpStart  = emergeEnd
        let moveUpEnd    = CGFloat(rel + 1) * phaseDuration

        if p >= moveUpEnd {
            return listSlot(for: rel)
        }
        if p >= moveUpStart {
            let t = (p - moveUpStart) / phaseDuration
            return StackSlot.interpolate(from: .front, to: listSlot(for: rel), t: t)
        }
        if rel == 0 {
            // Front card starts already at .front; only the move-up phase
            // applies, and it begins immediately at progress 0.
            return .front
        }
        if p >= emergeStart {
            let t = (p - emergeStart) / phaseDuration
            return StackSlot.interpolate(from: compactSlot(for: rel), to: .front, t: t)
        }
        return compactSlot(for: rel)
    }

    /// Spacing between cards once they've fanned out into the vertical list.
    private let listSpacing: CGFloat = 12

    /// Compact slot for a given relative index. The first three are the
    /// Figma-defined slots; deeper cards sit invisibly behind the back card
    /// until the user scrolls (then they fade in at their list positions).
    private func compactSlot(for rel: Int) -> StackSlot {
        switch rel {
        case 0:  return .front
        case 1:  return .middle
        case 2:  return .back
        default:
            // Rel ≥ 3 — same physical position as the back card but fully
            // transparent so they're invisible in the compact stack.
            return StackSlot(
                width: StackSlot.back.width,
                height: StackSlot.back.height,
                yOffset: StackSlot.back.yOffset,
                opacity: 0,
                cornerRadius: StackSlot.back.cornerRadius,
                shadowRadius: StackSlot.back.shadowRadius,
                shadowSpread: StackSlot.back.shadowSpread
            )
        }
    }

    /// Position in the vertical list for a given relative index. Anchored at
    /// the back card's y-offset (so rel=2 lands there) and grows upward for
    /// lower rels and downward for higher ones.
    private func listSlot(for rel: Int) -> StackSlot {
        let firstY = StackSlot.back.yOffset - 2 * (StackSlot.front.height + listSpacing)
        return StackSlot(
            width: StackSlot.front.width,
            height: StackSlot.front.height,
            yOffset: firstY + CGFloat(rel) * (StackSlot.front.height + listSpacing),
            opacity: 1.0,
            cornerRadius: StackSlot.front.cornerRadius,
            shadowRadius: StackSlot.front.shadowRadius,
            shadowSpread: StackSlot.front.shadowSpread
        )
    }

    private func restingSlot(forRelativeIndex rel: Int) -> StackSlot {
        switch rel {
        case -1: return aboveTopRestSlot
        case 0:  return .front
        case 1:  return .middle
        case 2:  return .back
        default: return belowBackRestSlot
        }
    }

    /// Resting position for the previously-dismissed card. Sits above the
    /// front slot at **opacity 0** — invisible until you start scrolling
    /// backward, then it eases in toward the front slot.
    private var aboveTopRestSlot: StackSlot {
        StackSlot(
            width: StackSlot.front.width,
            height: StackSlot.front.height,
            yOffset: StackSlot.front.yOffset - 84,
            opacity: 0,
            cornerRadius: StackSlot.front.cornerRadius,
            shadowRadius: StackSlot.front.shadowRadius,
            shadowSpread: StackSlot.front.shadowSpread
        )
    }

    private var belowBackRestSlot: StackSlot {
        StackSlot(
            width: StackSlot.back.width,
            height: StackSlot.back.height,
            yOffset: StackSlot.back.yOffset + 84,
            opacity: 0,
            cornerRadius: StackSlot.back.cornerRadius,
            shadowRadius: StackSlot.back.shadowRadius,
            shadowSpread: StackSlot.back.shadowSpread
        )
    }

    // MARK: - Gesture

    private enum CommitDirection { case advance, retreat }

    private var scrollGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let proposed = dragBase + value.translation.height
                // Hard clamp at both stable bounds — no rubber-banding past
                // the fully-expanded or fully-compact position.
                dragOffset = max(expandedOffset, min(collapsedOffset, proposed))
            }
            .onEnded { value in
                // Spring to the nearer stable state; velocity overrides the
                // midpoint check for a flick gesture.
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let midpoint = (collapsedOffset + expandedOffset) / 2
                let target: CGFloat
                if velocity < -300 {
                    target = expandedOffset
                } else if velocity > 300 {
                    target = collapsedOffset
                } else {
                    target = dragOffset < midpoint ? expandedOffset : collapsedOffset
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    dragOffset = target
                }
                dragBase = target
            }
    }

    /// Apply rubber-band resistance when the user tries to scroll past the
    /// first or last card — the drag still registers but at 25% effect.
    private func clampDragForBoundary(_ raw: CGFloat) -> CGFloat {
        let canAdvance = topIndex < cards.count - 1
        let canRetreat = topIndex > 0
        if raw < 0 && !canAdvance { return raw * 0.25 }
        if raw > 0 && !canRetreat { return raw * 0.25 }
        return raw
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
            dragOffset = 0
        }
    }

    private func commit(direction: CommitDirection) {
        isCommitting = true
        // Drive `dragOffset` far enough that `frontXOffset` carries the front
        // card off the side of the screen at the same slow follow rate used
        // during drag — no extra fast snap. The back cards' slot interp
        // clamps at ±1 so overshooting the range is harmless for them.
        let target: CGFloat = direction == .advance ? -2400 : 2400

        withAnimation(.spring(response: 0.85, dampingFraction: 0.95)) {
            dragOffset = target
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                switch direction {
                case .advance: topIndex = min(topIndex + 1, cards.count - 1)
                case .retreat: topIndex = max(topIndex - 1, 0)
                }
                dragOffset = 0
                isCommitting = false
            }
        }
    }
}
