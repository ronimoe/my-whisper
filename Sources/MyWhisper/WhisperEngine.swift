import Foundation
import CWhisper

/// In-process speech-to-text backend: links libwhisper directly and keeps the
/// model resident in this process instead of talking to a whisper-server
/// subprocess over HTTP. The whisper context is not concurrency-safe, so all
/// inference is serialized on a private queue.
final class WhisperEngine: TranscriptionEngine {
    /// Guards `_state` so the enum-with-String payload is never read or written
    /// concurrently by the main thread (start/stop) and the serial `queue` (the
    /// load's terminal .ready/.failed write). Distinct from `contextLock`; the
    /// two are never held nested — see `stop()`.
    private let stateLock = NSLock()
    private var _state: EngineState = .stopped
    var state: EngineState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _state
    }
    var onStateChange: ((EngineState) -> Void)?

    /// Single synchronized writer: commits `newValue` under the lock, captures the
    /// callback, then fires `onStateChange` OUTSIDE the lock so a callback that
    /// reads `state` cannot deadlock and callbacks are never delivered while the
    /// lock is held.
    private func setState(_ newValue: EngineState) {
        stateLock.lock()
        _state = newValue
        let callback = onStateChange
        stateLock.unlock()
        callback?(newValue)
    }

    /// Compare-and-set: atomically applies `newValue` only if `predicate` holds
    /// for the current state, evaluated under the same lock as the write. Returns
    /// whether the transition happened. `onStateChange` fires outside the lock.
    /// Lets a `stop()` that already set `.stopped` win over the queue's terminal
    /// `.ready`/`.failed` write.
    @discardableResult
    func transition(to newValue: EngineState, onlyIf predicate: (EngineState) -> Bool) -> Bool {
        stateLock.lock()
        guard predicate(_state) else {
            stateLock.unlock()
            return false
        }
        _state = newValue
        let callback = onStateChange
        stateLock.unlock()
        callback?(newValue)
        return true
    }

    let modelURL: URL

    /// Serializes every touch of the whisper context (load, inference, free).
    private let queue = DispatchQueue(label: "com.mywhisper.engine")
    /// Guards `context` against races between `stop`/`deinit` and inference.
    private let contextLock = NSLock()
    private var context: OpaquePointer?

    init(modelURL: URL) {
        self.modelURL = modelURL
        Self.silenceWhisperLoggingOnce()
        Self.loadBackendsOnce()
    }

    deinit {
        // Backstop only: AppDelegate calls stop() before releasing the engine,
        // so context is normally already nil here. The serial queue is being
        // torn down with self, so free the raw pointer directly rather than via
        // an async closure that would capture self.
        contextLock.lock()
        let ctx = context
        context = nil
        contextLock.unlock()
        if let ctx { whisper_free(ctx) }
    }

    struct TranscriptionError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func start() {
        guard case .stopped = state else { return }
        setState(.starting)
        let path = modelURL.path
        queue.async { [weak self] in
            guard let self else { return }
            var params = whisper_context_default_params()
            params.use_gpu = true
            let ctx = path.withCString { whisper_init_from_file_with_params($0, params) }
            guard let ctx else {
                // Only report load failure if a stop() hasn't already claimed
                // teardown; the check + write are atomic under stateLock.
                self.transition(to: .failed("could not load model \(self.modelURL.lastPathComponent)")) {
                    current in
                    if case .starting = current { return true }
                    return false
                }
                return
            }
            // Publish the context first (as before), then promote to .ready only
            // if still .starting. If a stop() already set .stopped, the promotion
            // is a no-op; because whisper_free runs on this same serial queue and
            // stop() dispatched it after we return, we hand the pointer to stop()
            // to free. stop() nulls context under contextLock and dispatches the
            // free — so store under contextLock here to stay ordered with it.
            self.contextLock.lock()
            self.context = ctx
            self.contextLock.unlock()
            let published = self.transition(to: .ready) { current in
                if case .starting = current { return true }
                return false
            }
            if !published {
                // A concurrent stop() won the state race. It may have already
                // taken the pointer (context == nil here) and dispatched the free,
                // or it may have set .stopped before we stored context. Reclaim
                // whatever is still ours and free it on this serial queue, which
                // is the sole owner of the context.
                self.contextLock.lock()
                let leaked = self.context
                self.context = nil
                self.contextLock.unlock()
                if let leaked { whisper_free(leaked) }
            }
        }
    }

    func stop() {
        // Flip state synchronously so no new work is accepted and the UI/poll
        // sees .stopped immediately. Then serialize the free onto `queue` so it
        // runs strictly after any in-flight or already-queued transcribe on that
        // serial queue finishes — the queue is the sole owner of the context, so
        // whisper_full never runs against a freed pointer. Nulling `context`
        // under the lock also makes a subsequent transcribe guard see nil.
        //
        // The state write and the context free are two SEPARATE critical
        // sections: stateLock (via setState) is released before contextLock is
        // taken, so the two locks are never held nested and cannot deadlock.
        setState(.stopped)
        contextLock.lock()
        let ctx = context
        context = nil
        contextLock.unlock()
        guard let ctx else { return } // never started, or already stopped
        queue.async { whisper_free(ctx) }
    }

    /// Blocks until any queued work (including the free dispatched by `stop`)
    /// has run. For headless callers that `exit()` right after stopping and
    /// must let the context — and its Metal resources — be released before
    /// ggml's static teardown runs. Never call from the main thread while an
    /// inference may be in flight; it is a serial-queue barrier.
    func waitForPendingWork() {
        queue.sync {}
    }

    func transcribe(samples: [Float], language: String, translate: Bool,
                    prompt: String?) async throws -> String {
        guard !samples.isEmpty else { return "" }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: TranscriptionError(message: "engine deallocated"))
                    return
                }
                self.contextLock.lock()
                let ctx = self.context
                self.contextLock.unlock()
                guard let ctx else {
                    continuation.resume(throwing: TranscriptionError(message: "model not loaded"))
                    return
                }
                do {
                    let text = try Self.runFull(ctx: ctx, samples: samples, language: language,
                                                translate: translate, prompt: prompt)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Runs `whisper_full` synchronously. Must be called on `queue`.
    /// The `language`/`initial_prompt` C strings are copied into
    /// `strdup`-owned buffers that outlive the whole `whisper_full` call.
    private static func runFull(ctx: OpaquePointer, samples: [Float], language: String,
                                translate: Bool, prompt: String?) throws -> String {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.translate = translate
        params.n_threads = Int32(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))

        // strdup gives us stable pointers that live until we free them below,
        // guaranteeing the C strings outlive the whisper_full call.
        let languageC = strdup(language)
        let promptC: UnsafeMutablePointer<CChar>?
        if let prompt, !prompt.isEmpty {
            promptC = strdup(prompt)
        } else {
            promptC = nil
        }
        defer {
            free(languageC)
            free(promptC)
        }
        params.language = UnsafePointer(languageC)
        params.initial_prompt = promptC.map { UnsafePointer($0) }

        let status = samples.withUnsafeBufferPointer { buffer in
            whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
        }
        guard status == 0 else {
            throw TranscriptionError(message: "whisper_full failed (code \(status))")
        }

        var result = ""
        let segmentCount = whisper_full_n_segments(ctx)
        for i in 0..<segmentCount {
            if let segment = whisper_full_get_segment_text(ctx, i) {
                result += String(cString: segment)
            }
        }
        return result
    }

    /// Route libwhisper's stderr logging to a no-op so a GUI run stays quiet.
    private static let silenceLogging: Void = {
        whisper_log_set({ _, _, _ in }, nil)
    }()

    private static func silenceWhisperLoggingOnce() {
        _ = silenceLogging
    }

    /// Registers ggml's dynamically-loaded backends (Metal, CPU). whisper_init
    /// aborts on GGML_ASSERT(device) if no backend has been loaded, so this must
    /// run before the first whisper_init_from_file_with_params. Idempotent, but
    /// gated to run exactly once. Honors $GGML_BACKEND_PATH; falls back to the
    /// libexec dir baked into libggml.
    private static let loadBackends: Void = {
        ggml_backend_load_all()
    }()

    private static func loadBackendsOnce() {
        _ = loadBackends
    }
}
