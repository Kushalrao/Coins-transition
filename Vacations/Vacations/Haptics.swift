//
//  Haptics.swift
//  Vacations
//
//  Small haptics helper for the rewards sequence:
//   • `tickerBurst()` — a run of medium impacts while the earned amount tickers
//     in.
//   • `startContinuousLow()` / `stopContinuous()` — a low, continuous rumble
//     (CoreHaptics) while the particles stream up.
//
//  Note: haptics only fire on a physical device; on the Simulator these are
//  no-ops (the calls are still safe).
//

import UIKit
import CoreHaptics

final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticPatternPlayer?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        // Restart the engine if the system stops it (e.g. after an interruption).
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
    }

    /// A short run of medium impacts to accompany the earned-amount ticker.
    func tickerBurst(count: Int = 11, over seconds: Double = 1.15) {
        Task { @MainActor in
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            let interval = UInt64(max(0.04, seconds / Double(count)) * 1_000_000_000)
            for _ in 0..<count {
                gen.impactOccurred(intensity: 0.85)
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    /// Begins a low-intensity continuous rumble (used while particles move up).
    func startContinuousLow() {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.32),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18),
            ],
            relativeTime: 0,
            duration: 30)
        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makePlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            continuousPlayer = nil
        }
    }

    /// Stops the continuous rumble.
    func stopContinuous() {
        try? continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        continuousPlayer = nil
    }
}
