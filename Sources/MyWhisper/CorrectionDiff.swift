import Foundation

/// Derives reusable find→replace rules from a user's manual correction of a
/// transcript, so the same mistake can be auto-fixed next time.
enum CorrectionDiff {
    private static let maxFindLength = 60

    /// Derives a single find→replace rule from an original transcript and the
    /// user's corrected version, by trimming the longest common prefix and
    /// suffix aligned to word boundaries. Returns nil when no sane rule
    /// exists (identical strings, an empty find, no actual change, or a find
    /// too broad to safely auto-apply).
    static func suggestRule(original: String, corrected: String) -> (find: String, replace: String)? {
        guard original != corrected else { return nil }

        let o = Array(original)
        let c = Array(corrected)

        // Longest common prefix, character by character.
        var prefixEnd = 0
        while prefixEnd < o.count, prefixEnd < c.count, o[prefixEnd] == c[prefixEnd] {
            prefixEnd += 1
        }
        // Back the prefix off to the previous word boundary so `find` starts
        // at the beginning of a whole word, not mid-word.
        while prefixEnd > 0, o[prefixEnd - 1] != " " {
            prefixEnd -= 1
        }

        // Longest common suffix, not overlapping the (pre-backoff) prefix.
        var suffixLen = 0
        while suffixLen < o.count - prefixEnd,
              suffixLen < c.count - prefixEnd,
              o[o.count - 1 - suffixLen] == c[c.count - 1 - suffixLen] {
            suffixLen += 1
        }
        // Back the suffix off to the next word boundary (forward), so it
        // starts right after a space, without crossing back into the prefix.
        var suffixStartO = o.count - suffixLen
        while suffixStartO < o.count, suffixStartO > prefixEnd, o[suffixStartO - 1] != " " {
            suffixStartO += 1
        }
        suffixLen = o.count - suffixStartO

        // Re-clamp prefix in case the suffix back-off walked past it in
        // either string (short strings / heavily overlapping edits).
        let suffixStartC = c.count - suffixLen
        prefixEnd = min(prefixEnd, suffixStartO, suffixStartC)

        let midO = String(o[prefixEnd..<(o.count - suffixLen)])
        let midC = String(c[prefixEnd..<(c.count - suffixLen)])

        let find = midO.trimmingCharacters(in: .whitespaces)
        let replace = midC.trimmingCharacters(in: .whitespaces)

        guard !find.isEmpty, find != replace, find.count <= maxFindLength else { return nil }
        return (find, replace)
    }
}
