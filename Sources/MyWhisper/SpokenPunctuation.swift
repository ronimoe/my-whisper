import Foundation

/// Replaces spoken punctuation words (English and Indonesian) with their
/// symbol equivalents, e.g. "halo koma apa kabar titik" → "halo, apa kabar."
/// Off by default; see Settings.spokenPunctuationEnabled.
enum SpokenPunctuation {

    /// Ordered longest-phrase-first so multi-word tokens (e.g. "titik dua")
    /// are matched before their single-word prefixes/suffixes ("titik").
    private static let tokenTable: [(phrase: String, symbol: String)] = [
        // Multi-word tokens first (longest match wins).
        ("full stop", "."),
        ("question mark", "?"),
        ("exclamation mark", "!"),
        ("new paragraph", "\n\n"),
        ("new line", "\n"),
        ("titik dua", ":"),
        ("titik koma", ";"),
        ("tanda tanya", "?"),
        ("tanda seru", "!"),
        ("paragraf baru", "\n\n"),
        ("baris baru", "\n"),
        // Single-word tokens.
        ("comma", ","),
        ("period", "."),
        ("colon", ":"),
        ("semicolon", ";"),
        ("koma", ","),
        ("titik", "."),
    ]

    /// Symbols that get no surrounding space (they are inherently a line break).
    private static let newlineSymbols: Set<String> = ["\n", "\n\n"]

    /// Symbols after which the following word is capitalized: the sentence
    /// enders (. ? !) plus the newline tokens, which also start a new
    /// capitalized line.
    private static let capitalizingSymbols: Set<String> = [".", "?", "!", "\n", "\n\n"]

    static func apply(to text: String) -> String {
        guard !text.isEmpty else { return text }

        let pattern = tokenTable
            .map { NSRegularExpression.escapedPattern(for: $0.phrase) }
            .joined(separator: "|")
        let fullPattern = "\\b(?:\(pattern))\\b"

        guard let regex = try? NSRegularExpression(pattern: fullPattern, options: [.caseInsensitive]) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        // Split the string into: prefix, [symbol, gap]*, using the gap after
        // each token to hold the literal text up to the next token (or end
        // of string). Each gap gets: duplicate-collapse of the symbol that
        // precedes it, trailing-space-before-next-token stripped, and
        // capitalization applied if its symbol was a sentence-ender.
        var result = ""
        var cursor = 0
        var pendingSymbol: String? // symbol whose trailing spacing/capitalization still needs resolving

        for (index, match) in matches.enumerated() {
            let matchRange = match.range
            guard matchRange.location >= cursor else { continue } // overlapping, skip

            let gapEnd = matchRange.location
            var gap = nsText.substring(with: NSRange(location: cursor, length: gapEnd - cursor))

            if let pendingSymbol {
                gap = collapseDuplicate(of: pendingSymbol, from: gap)
                gap = resolveTrailing(of: pendingSymbol, text: gap, hasMoreText: true)
            }

            // Strip a single trailing space right before this token so the
            // symbol attaches to the preceding word.
            if gap.hasSuffix(" ") {
                gap.removeLast()
            }

            result += gap

            let matchedPhrase = nsText.substring(with: matchRange).lowercased()
            let symbol = tokenTable.first(where: { $0.phrase == matchedPhrase })?.symbol ?? ""
            result += symbol
            pendingSymbol = symbol

            cursor = matchRange.location + matchRange.length
            _ = index
        }

        // Trailing text after the last match.
        var tail = nsText.substring(from: cursor)
        if let pendingSymbol {
            tail = collapseDuplicate(of: pendingSymbol, from: tail)
            tail = resolveTrailing(of: pendingSymbol, text: tail, hasMoreText: !tail.isEmpty)
        }
        result += tail

        return result
    }

    /// Strips a leading duplicate of `symbol` from `text` (allowing a single
    /// space before it), so a token immediately followed by whisper's own
    /// identical punctuation collapses into one, e.g. "koma, apa" -> ", apa"
    /// (token already replaced) with the stray "," removed.
    private static func collapseDuplicate(of symbol: String, from text: String) -> String {
        if text.hasPrefix(symbol) {
            var s = text
            s.removeFirst(symbol.count)
            return s
        }
        let spacedPrefix = " " + symbol
        if text.hasPrefix(spacedPrefix) {
            var s = text
            s.removeFirst(spacedPrefix.count)
            return s
        }
        return text
    }

    /// Applies spacing/capitalization rules for the text immediately
    /// following a replaced `symbol`: exactly one space before any remaining
    /// text (none if the string ends there), and the first letter uppercased
    /// when `symbol` is a sentence-ender. Newline symbols get no extra space.
    private static func resolveTrailing(of symbol: String, text: String, hasMoreText: Bool) -> String {
        var remainder = text
        while remainder.hasPrefix(" ") {
            remainder.removeFirst()
        }

        guard !remainder.isEmpty else {
            return ""
        }

        if capitalizingSymbols.contains(symbol) {
            remainder = capitalizeFirstLetter(of: remainder)
        }

        if newlineSymbols.contains(symbol) {
            return remainder
        }
        return " " + remainder
    }

    private static func capitalizeFirstLetter(of s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst()
    }
}
