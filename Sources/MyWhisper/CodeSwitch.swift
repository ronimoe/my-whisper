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

    /// Priming prompt for Tagalog + English code-switching ("mixed-tl").
    static let tlPrimingExample = "Sige, i-follow up natin yung meeting bukas ng umaga, tapos i-update mo yung slides bago yung presentation sa client, ha?"

    /// Priming prompt for Hindi + English code-switching ("mixed-hi").
    static let hiPrimingExample = "ठीक है, कल morning में meeting fix कर लो, फिर client को timeline और budget approval के बारे में update भेज दो।"

    /// Priming prompt for Spanish + English code-switching ("mixed-es").
    static let esPrimingExample = "Bueno, mañana temprano tenemos el meeting con el cliente, así que actualiza el deck y manda el follow-up del budget, ¿vale?"

    /// Priming prompt for Chinese + English code-switching ("mixed-zh").
    static let zhPrimingExample = "好，明天早上先开个 meeting，然后把 deck 更新一下，再 follow up 一下 client 的 timeline 和 budget approval。"

    /// Fixed-primary code-switched pairs beyond the original "mixed" (id+en,
    /// which honors the caller-supplied `primary`). Each entry pins a fixed
    /// primary language regardless of the caller's `primary` argument.
    private static let pairs: [String: (primary: String, priming: String)] = [
        "mixed-tl": ("tl", tlPrimingExample),
        "mixed-hi": ("hi", hiPrimingExample),
        "mixed-es": ("es", esPrimingExample),
        "mixed-zh": ("zh", zhPrimingExample),
    ]

    /// Maps the user-selected language + lexicon vocabulary prompt into the
    /// (language, prompt) actually sent to whisper.
    static func requestParameters(language: String, primary: String, vocabularyPrompt: String?) -> (language: String, prompt: String?) {
        if language == "id" {
            if let vocabularyPrompt, !vocabularyPrompt.isEmpty {
                return ("id", vocabularyPrompt + ". " + idPunctuationPriming)
            }
            return ("id", idPunctuationPriming)
        }
        if language == mixedCode {
            if let vocabularyPrompt, !vocabularyPrompt.isEmpty {
                return (primary, vocabularyPrompt + ". " + primingExample)
            }
            return (primary, primingExample)
        }
        if let pair = pairs[language] {
            if let vocabularyPrompt, !vocabularyPrompt.isEmpty {
                return (pair.primary, vocabularyPrompt + ". " + pair.priming)
            }
            return (pair.primary, pair.priming)
        }
        return (language, vocabularyPrompt)
    }
}
