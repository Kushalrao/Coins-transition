import SwiftUI

// MARK: - iOS 16 back-deployment
//
// The prototype is built against iOS 17 APIs — Metal shader effects, keyframe
// animators, the MapKit content builder. The deployment target is 16.0 so it
// can be run on hardware that never got iOS 17 (an iPhone X tops out at 16.7),
// which means each of those has to be reached through a guard.
//
// Everything here degrades rather than substitutes: on iOS 16 the affected
// surface loses its shader or its keyframe choreography and falls back to the
// plainest thing that still reads. The motion design is only fully itself on
// iOS 17+, and that is where it should be judged.

extension View {
    /// `onChange(of:)` across both generations. The two-parameter closure
    /// arrived in iOS 17 and the one-parameter form is deprecated there, so this
    /// picks whichever the running OS actually has.
    @ViewBuilder
    func onValueChange<V: Equatable>(of value: V,
                                     perform: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in perform(newValue) }
        } else {
            self.onChange(of: value) { newValue in perform(newValue) }
        }
    }

    /// Film grain over the trip-page header wash. No shader on iOS 16, so the
    /// wash simply reads as a clean gradient there.
    @ViewBuilder
    func grainOverlay(_ intensity: Float) -> some View {
        if #available(iOS 17.0, *) {
            self.colorEffect(ShaderLibrary.grain(.float(intensity)))
        } else {
            self
        }
    }
}
