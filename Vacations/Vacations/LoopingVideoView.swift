//
//  LoopingVideoView.swift
//  Vacations
//
//  Plays a bundled video. By default it loops; with `playOnce` it plays the
//  clip a single time and holds on the final frame (used for the scapía coin
//  that morphs into the energy bolt — the gif's last frame IS the bolt). The
//  clip has an opaque background, so no transparency handling is needed.
//

import SwiftUI
import UIKit
import AVFoundation

struct LoopingVideoView: UIViewRepresentable {
    let resource: String        // file name without extension
    let ext: String             // file extension, e.g. "mp4"
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var playOnce: Bool = false  // play once and hold the last frame
    var rate: Float = 1.0       // playback speed

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(resource: resource, ext: ext, gravity: gravity,
                     playOnce: playOnce, rate: rate)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    /// Hosts an `AVPlayerLayer`. Loops via `AVPlayerLooper`, or plays once and
    /// pauses on the final frame.
    final class PlayerUIView: UIView {
        private var looper: AVPlayerLooper?
        private let queuePlayer = AVQueuePlayer()
        private let playOnce: Bool
        private let rate: Float

        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        init(resource: String, ext: String, gravity: AVLayerVideoGravity,
             playOnce: Bool, rate: Float) {
            self.playOnce = playOnce
            self.rate = rate
            super.init(frame: .zero)
            backgroundColor = .clear
            playerLayer.videoGravity = gravity
            playerLayer.player = queuePlayer
            queuePlayer.isMuted = true
            // Play once → freeze on the last frame; loop → restart seamlessly.
            queuePlayer.actionAtItemEnd = playOnce ? .pause : .advance

            if let url = Bundle.main.url(forResource: resource, withExtension: ext) {
                let item = AVPlayerItem(url: url)
                if playOnce {
                    queuePlayer.insert(item, after: nil)
                } else {
                    looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
                }
                queuePlayer.playImmediately(atRate: rate)
            }

            // Resume if playback is interrupted (e.g. returning to foreground).
            NotificationCenter.default.addObserver(
                self, selector: #selector(resume),
                name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        @objc private func resume() {
            // Don't restart a finished one-shot; just keep showing its last frame.
            if playOnce, let item = queuePlayer.currentItem,
               item.currentTime() >= item.duration { return }
            queuePlayer.playImmediately(atRate: rate)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}
