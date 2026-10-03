import Foundation
import AVFoundation

/// `NarrationAudioRenderer` on `AVSpeechSynthesizer.write(_:toBufferCallback:)` — the same
/// voices (Personal Voice included) as the live narrator, rendered to a temp .caf file.
final class SpeechNarrationAudioRenderer: NarrationAudioRenderer {

    enum Failure: Error { case noAudio, timedOut }

    /// Generous: a 30-second script renders in a few seconds, but never hang an export on it.
    private static let timeout: Duration = .seconds(60)

    func renderAudio(script: String, voiceID: String?) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("listingreel_voiceover_\(UUID().uuidString).caf")
        let job = WriteJob(url: url)
        let utterance = SpeechUtteranceFactory.make(script: script, voiceID: voiceID)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // The task group waits for every child before returning, so the write
                // must end on cancellation (timeout, or the export being cancelled).
                group.addTask {
                    try await withTaskCancellationHandler {
                        try await job.run(utterance)
                    } onCancel: {
                        job.cancel()
                    }
                }
                group.addTask {
                    try await Task.sleep(for: Self.timeout)
                    throw Failure.timedOut
                }
                defer { group.cancelAll() }
                try await group.next()
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        return url
    }
}

/// Owns the synthesizer and output file for one render. `write`'s callback arrives on an
/// arbitrary queue, so all state is guarded by a lock.
private final class WriteJob: @unchecked Sendable {
    private let url: URL
    private let synthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var framesWritten: AVAudioFramePosition = 0
    private var continuation: CheckedContinuation<Void, Error>?
    private var isCancelled = false

    init(url: URL) { self.url = url }

    func run(_ utterance: AVSpeechUtterance) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let alreadyCancelled = lock.withLock {
                self.continuation = continuation
                return isCancelled
            }
            guard !alreadyCancelled else { return finish(CancellationError()) }
            synthesizer.write(utterance) { [self] buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                // A zero-length buffer marks the end of the utterance.
                guard pcm.frameLength > 0 else {
                    finish(framesWritten > 0 ? nil : SpeechNarrationAudioRenderer.Failure.noAudio)
                    return
                }
                do {
                    try lock.withLock {
                        if file == nil {
                            file = try AVAudioFile(forWriting: url, settings: pcm.format.settings,
                                                   commonFormat: pcm.format.commonFormat,
                                                   interleaved: pcm.format.isInterleaved)
                        }
                        try file?.write(from: pcm)
                        framesWritten += AVAudioFramePosition(pcm.frameLength)
                    }
                } catch {
                    finish(error)
                }
            }
        }
    }

    func cancel() {
        lock.withLock { isCancelled = true }
        synthesizer.stopSpeaking(at: .immediate)
        finish(CancellationError())
    }

    private func finish(_ error: Error?) {
        let continuation = lock.withLock {
            file = nil   // releasing the AVAudioFile flushes and closes it
            defer { self.continuation = nil }
            return self.continuation
        }
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }
}

/// One place that turns a script + chosen voice into an utterance, so the live narration
/// and the rendered file sound identical.
enum SpeechUtteranceFactory {
    static func make(script: String, voiceID: String?) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: script)
        utterance.voice = voiceID.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.prefersAssistiveTechnologySettings = false
        return utterance
    }
}
