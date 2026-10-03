import AVFoundation

/// Preview video and the AI voiceover are content the agent explicitly asked to hear, so
/// they must play with the Silent switch on. The default `.soloAmbient` category mutes them.
/// No-op on macOS, which has no app audio session.
enum PlaybackAudioSession {
    static func activate() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        #endif
    }
}
