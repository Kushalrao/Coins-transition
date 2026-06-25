//
//  SlideToUnlockButton.swift
//  Vacations
//
//  Slide-to-unlock control used at the bottom of the rewards screen.
//  Drag the thumb across the track; once it crosses the commit threshold
//  (set by `commitRatio`), the binding flips to true and the thumb locks
//  at the right end. If released short of the threshold, the thumb
//  springs back to the start.
//

import SwiftUI

struct SlideToUnlockButton: View {
    @Binding var isUnlocked: Bool
    /// Live drag progress 0 → 1 while the user is dragging the thumb.
    /// On a successful commit it springs back to 0 (the thumb stays
    /// visually at the end via `isUnlocked`) so observers — like the
    /// reward stack on the rewards screen — can use it to drive a
    /// "scroll down while dragging, snap up on release" reveal.
    @Binding var dragProgress: CGFloat

    var trackHeight: CGFloat = 56
    /// Inset between the track edge and the thumb, all around.
    var trackPadding: CGFloat = 4
    /// Fraction of the track the user must drag across before release
    /// commits to the unlocked state.
    var commitRatio: CGFloat = 0.8
    var lockedLabel: String = "Slide to unlock"
    var unlockedLabel: String = "Unlocked"

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = proxy.size.width
            let thumbSize = trackHeight - trackPadding * 2
            let maxDrag = max(0, trackWidth - thumbSize - trackPadding * 2)
            // The commit logic uses `currentOffset` so an external state flip
            // (e.g. setting isUnlocked = true programmatically) renders the
            // thumb at the unlocked position too.
            let currentOffset = isUnlocked ? maxDrag : dragOffset

            ZStack(alignment: .leading) {
                // Track. Glass-card style to match the trip card's pill.
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                    )

                // Filled progress behind the thumb. Gives the user feedback
                // on how far they've dragged.
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: currentOffset + thumbSize + trackPadding * 2)

                // Centered label. Fades out as the thumb advances.
                Text(isUnlocked ? unlockedLabel : lockedLabel)
                    .font(DesignFont.semibold(15))
                    .foregroundColor(Color.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(isUnlocked ? 1 : 1 - Double(currentOffset / max(maxDrag, 1)))

                // Thumb.
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        Image(systemName: isUnlocked ? "checkmark" : "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignColors.textHighEmphasis)
                    )
                    .padding(trackPadding)
                    .offset(x: currentOffset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !isUnlocked else { return }
                                let proposed = max(0, min(maxDrag, value.translation.width))
                                dragOffset = proposed
                                dragProgress = maxDrag > 0 ? proposed / maxDrag : 0
                            }
                            .onEnded { _ in
                                guard !isUnlocked else { return }
                                if dragOffset >= maxDrag * commitRatio {
                                    // Commit: thumb locks visually at the
                                    // end (via isUnlocked = true), but
                                    // dragProgress springs back to 0 so the
                                    // observed content (e.g. the reward
                                    // stack) snaps up to its rest position
                                    // — revealing the unlocked imagery.
                                    withAnimation(.spring(response: 0.55,
                                                          dampingFraction: 0.78)) {
                                        dragOffset = maxDrag
                                        isUnlocked = true
                                        dragProgress = 0
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.4,
                                                          dampingFraction: 0.78)) {
                                        dragOffset = 0
                                        dragProgress = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: trackHeight)
    }
}
