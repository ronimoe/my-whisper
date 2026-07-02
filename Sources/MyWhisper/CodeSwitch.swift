import Foundation

/// Supports the "Mixed language" dictation option: Whisper takes a single
/// `language` per request, so mixed-language speech (e.g. Indonesian tech
/// speech peppered with English) is instead handled by pinning a primary
/// language and priming the decoder with a code-switched `prompt`.
enum CodeSwitch {
    static let mixedCode = "mixed"

    static let primingExample = "Oke, jadi untuk meeting besok kita perlu update deck-nya dulu, terus follow up ke client soal timeline sama budget approval, ya."

    /// Priming prompt used for plain Indonesian dictation ("id"): Whisper's
    /// punctuation style follows the initial prompt, so this nudges it
    /// toward natural comma/period usage.
    static let idPunctuationPriming = "Baik, jadi rencananya begini: besok pagi kita rapat dulu, lalu siangnya presentasi ke tim, dan sorenya evaluasi. Setuju, ya?"

    /// Maps the user-selected language + lexicon vocabulary prompt into the
    /// (language, prompt) actually sent to whisper.
    static func requestParameters(language: String, primary: String, vocabularyPrompt: String?) -> (language: String, prompt: String?) {
        if language == "id" {
            if let vocabularyPrompt, !vocabularyPrompt.isEmpty {
                return ("id", vocabularyPrompt + ". " + idPunctuationPriming)
            }
            return ("id", idPunctuationPriming)
        }
        guard language == mixedCode else {
            return (language, vocabularyPrompt)
        }
        if let vocabularyPrompt, !vocabularyPrompt.isEmpty {
            return (primary, vocabularyPrompt + ". " + primingExample)
        }
        return (primary, primingExample)
    }
}
