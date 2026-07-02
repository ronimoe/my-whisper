import Foundation

/// Lifecycle state shared by every transcription backend.
enum EngineState {
    case stopped
    case starting
    case ready
    case failed(String)
}

/// A speech-to-text backend. Two implementations exist:
/// `WhisperServerManager` (whisper-server subprocess over HTTP) and
/// `WhisperEngine` (libwhisper linked in-process). Callers hand raw float
/// samples straight in; each engine encodes/decodes them as it needs.
protocol TranscriptionEngine: AnyObject {
    var state: EngineState { get }
    var onStateChange: ((EngineState) -> Void)? { get set }
    func start()
    func stop()
    func transcribe(samples: [Float], language: String, translate: Bool,
                    prompt: String?) async throws -> String
}
