import Foundation

/// The result of running a dictation through the shared pipeline.
///
/// - `command`: the utterance was, in full, a recognized spoken command
///   (e.g. "scratch that"); the caller should execute it and NOT paste/print.
/// - `text`: normal transcribed text ready to paste/print.
/// - `empty`: nothing usable was transcribed (e.g. silence or a noise-only
///   annotation); the caller should do nothing.
enum DictationOutcome: Equatable {
    case command(VoiceCommand)
    case text(String)
    case empty
}

/// The full result of `DictationPipeline.run`: the outcome plus, when an AI
/// mode was requested but the Ollama rewrite failed, the error that caused the
/// fall back to the raw transcript. Callers surface `aiFailure` however suits
/// them (the GUI shows a notification; the CLI prints a stderr note); the
/// `outcome` itself is identical whether or not the rewrite succeeded.
struct DictationResult {
    let outcome: DictationOutcome
    /// Non-nil only when a non-Raw mode was applied and `Ollama.rewrite` threw;
    /// in that case `outcome` carries the un-rewritten `.text`.
    let aiFailure: Error?
}

/// The shared transcription → post-processing → AI-mode pipeline used by both
/// the GUI (`AppDelegate.finishDictation`) and the CLI (`HeadlessRunner.run`).
/// Extracted so the two call sites can't drift apart.
struct DictationPipeline {
    let engine: any TranscriptionEngine

    /// The pure, engine-free core of the pipeline: turns a raw whisper
    /// transcript into a `DictationOutcome`.
    ///
    /// Order (must match both former inline call sites exactly):
    /// 1. `Postprocess.clean` normalizes whitespace / drops noise annotations.
    /// 2. `lexicon.apply` runs user find/replace substitutions.
    /// 3. If voice commands are enabled and the (non-empty) cleaned text is
    ///    *entirely* a known command, return `.command` immediately — BEFORE
    ///    spoken punctuation, so e.g. "new paragraph" spoken alone stays a
    ///    command rather than becoming "\n\n".
    /// 4. Otherwise, if spoken punctuation is enabled, apply it.
    /// 5. An empty result maps to `.empty` (no paste/print); anything else to
    ///    `.text`.
    static func process(rawTranscript: String, lexicon: Lexicon,
                        voiceCommandsEnabled: Bool, spokenPunctuationEnabled: Bool) -> DictationOutcome {
        var candidate = lexicon.apply(to: Postprocess.clean(rawTranscript))

        if voiceCommandsEnabled, !candidate.isEmpty,
           let command = VoiceCommands.match(candidate) {
            return .command(command)
        }

        if spokenPunctuationEnabled {
            candidate = SpokenPunctuation.apply(to: candidate)
        }

        return candidate.isEmpty ? .empty : .text(candidate)
    }

    /// Orchestrates a full dictation: build CodeSwitch request parameters,
    /// transcribe, run `process`, and — for `.text` results in a non-Raw mode —
    /// rewrite via Ollama (falling back to the raw text on failure).
    ///
    /// `context` is the captured frontmost-app / selection used to substitute
    /// `{app}` / `{selection}` in the mode prompt; pass nil to use the mode
    /// prompt verbatim (the CLI does this). On AI-rewrite failure the returned
    /// `DictationResult.aiFailure` carries the error so the caller can notify,
    /// while `outcome` still holds the un-rewritten text.
    func run(samples: [Float], language: String, mixedPrimary: String, translate: Bool,
             lexicon: Lexicon, voiceCommandsEnabled: Bool, spokenPunctuationEnabled: Bool,
             modeName: String, modes: [Mode], context: ModeContext.Captured?,
             ollamaModel: String, ollamaBaseURL: URL) async throws -> DictationResult {
        let params = CodeSwitch.requestParameters(language: language,
                                                  primary: mixedPrimary,
                                                  vocabularyPrompt: lexicon.vocabularyPrompt)
        let raw = try await engine.transcribe(samples: samples, language: params.language,
                                              translate: translate, prompt: params.prompt)

        return await Self.finishFromRawTranscript(
            raw, lexicon: lexicon, voiceCommandsEnabled: voiceCommandsEnabled,
            spokenPunctuationEnabled: spokenPunctuationEnabled,
            modeName: modeName, modes: modes, context: context,
            ollamaModel: ollamaModel, ollamaBaseURL: ollamaBaseURL)
    }

    /// Same post-transcription pipeline as `run(samples:...)`, but starting
    /// from an already-transcribed raw string instead of audio — no engine
    /// call, no network for transcription. Used by fast-finalize, which
    /// reuses a live-preview partial's raw transcript instead of
    /// re-transcribing the full recording. Static because this path never
    /// touches `engine`.
    static func run(rawTranscript: String, lexicon: Lexicon, voiceCommandsEnabled: Bool,
                    spokenPunctuationEnabled: Bool, modeName: String, modes: [Mode],
                    context: ModeContext.Captured?, ollamaModel: String,
                    ollamaBaseURL: URL) async -> DictationResult {
        await finishFromRawTranscript(
            rawTranscript, lexicon: lexicon, voiceCommandsEnabled: voiceCommandsEnabled,
            spokenPunctuationEnabled: spokenPunctuationEnabled,
            modeName: modeName, modes: modes, context: context,
            ollamaModel: ollamaModel, ollamaBaseURL: ollamaBaseURL)
    }

    /// Shared tail of both `run` entry points: `process` the raw transcript,
    /// then — for `.text` results in a non-Raw mode — rewrite via Ollama
    /// (falling back to the raw text on failure). Factored out so the
    /// audio-driven and raw-transcript-driven entry points cannot drift.
    private static func finishFromRawTranscript(
        _ raw: String, lexicon: Lexicon, voiceCommandsEnabled: Bool,
        spokenPunctuationEnabled: Bool, modeName: String, modes: [Mode],
        context: ModeContext.Captured?, ollamaModel: String, ollamaBaseURL: URL
    ) async -> DictationResult {
        let outcome = process(rawTranscript: raw, lexicon: lexicon,
                              voiceCommandsEnabled: voiceCommandsEnabled,
                              spokenPunctuationEnabled: spokenPunctuationEnabled)

        guard case .text(let candidate) = outcome else {
            return DictationResult(outcome: outcome, aiFailure: nil)
        }

        guard modeName != "Raw",
              let mode = modes.first(where: { $0.name == modeName }) else {
            return DictationResult(outcome: outcome, aiFailure: nil)
        }

        let effectiveMode: Mode
        if let context {
            effectiveMode = Mode(name: mode.name,
                                 prompt: ModeContext.substitute(prompt: mode.prompt,
                                                                appName: context.appName,
                                                                selection: context.selection),
                                 model: mode.model)
        } else {
            effectiveMode = mode
        }

        do {
            let rewritten = try await Ollama.rewrite(text: candidate, mode: effectiveMode,
                                                     defaultModel: ollamaModel,
                                                     baseURL: ollamaBaseURL)
            return DictationResult(outcome: .text(rewritten), aiFailure: nil)
        } catch {
            return DictationResult(outcome: .text(candidate), aiFailure: error)
        }
    }
}
