import Foundation

/// Fuzzy search over pass entry paths (no decrypt).
///
/// Query is split on whitespace into tokens; every token must match the path
/// as a case-insensitive character subsequence (fzf-style AND). Example:
/// `"goo ac"` matches `google/account`.
enum EntrySearch {
    /// Entries that match `query`, best score first. Empty/whitespace query returns `entries` unchanged.
    static func ranked(_ entries: [String], query: String) -> [String] {
        let tokens = tokens(from: query)
        guard !tokens.isEmpty else { return entries }

        return entries.compactMap { entry -> (String, Int)? in
            guard let score = score(entry: entry, tokens: tokens) else { return nil }
            return (entry, score)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
        }
        .map(\.0)
    }

    static func matches(_ query: String, in entry: String) -> Bool {
        let tokens = tokens(from: query)
        guard !tokens.isEmpty else { return true }
        return score(entry: entry, tokens: tokens) != nil
    }

    // MARK: - Private

    private static func tokens(from query: String) -> [String] {
        query
            .split(whereSeparator: \.isWhitespace)
            .map { normalize(String($0)) }
            .filter { !$0.isEmpty }
    }

    private static func normalize(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func score(entry: String, tokens: [String]) -> Int? {
        let haystack = normalize(entry)
        var total = 0
        for token in tokens {
            guard let tokenScore = scoreToken(token, in: haystack) else { return nil }
            total += tokenScore
        }
        // Prefer shorter paths when token scores are similar.
        total -= min(haystack.count, 40)
        return total
    }

    /// Subsequence match with bonuses for adjacency and path-segment boundaries.
    private static func scoreToken(_ token: String, in haystack: String) -> Int? {
        guard !token.isEmpty else { return 0 }

        let haystackChars = Array(haystack)
        let tokenChars = Array(token)
        var haystackIndex = 0
        var score = 0
        var previousMatchIndex: Int?
        var firstMatchIndex: Int?

        for tokenChar in tokenChars {
            var found = false
            while haystackIndex < haystackChars.count {
                let index = haystackIndex
                haystackIndex += 1
                guard haystackChars[index] == tokenChar else { continue }

                var points = 1
                if let previousMatchIndex {
                    let gap = index - previousMatchIndex
                    if gap == 1 {
                        points += 8
                    } else {
                        points -= min(gap - 1, 4)
                    }
                }

                if isBoundary(before: index, in: haystackChars) {
                    points += previousMatchIndex == nil ? 12 : 6
                }

                score += points
                if firstMatchIndex == nil { firstMatchIndex = index }
                previousMatchIndex = index
                found = true
                break
            }
            if !found { return nil }
        }

        if let firstMatchIndex {
            score += max(0, 24 - firstMatchIndex)
        }
        return score
    }

    private static func isBoundary(before index: Int, in chars: [Character]) -> Bool {
        guard index > 0 else { return true }
        let previous = chars[index - 1]
        return previous == "/" || previous == "-" || previous == "_" || previous == "." || previous == " "
    }
}
