import Foundation

final class SynonymService {
    /// Primary index: exact lowercased word -> meaning groups
    private var thesaurus: [String: [[String]]] = [:]
    /// Secondary index: accent-stripped word -> list of original headwords
    private var strippedIndex: [String: [String]] = [:]

    var entryCount: Int { thesaurus.count }

    init() {
        loadThesaurus()
        buildStrippedIndex()
    }

    func fetchSynonyms(for word: String) -> [Synonym] {
        let cleaned = cleanWord(word)
        guard !cleaned.isEmpty else { return [] }

        // 1. Try exact match
        if let results = lookupResults(for: cleaned), !results.isEmpty {
            return results
        }

        // 2. Try NFC-normalized match
        let normalized = cleaned.precomposedStringWithCanonicalMapping
        if normalized != cleaned, let results = lookupResults(for: normalized), !results.isEmpty {
            return results
        }

        // 3. Try accent-stripped fallback
        let stripped = stripAccents(cleaned)
        if let headwords = strippedIndex[stripped] {
            // Try each original headword that maps to this stripped form
            for headword in headwords {
                if let results = lookupResults(for: headword), !results.isEmpty {
                    return results
                }
            }
        }

        // 4. If word contains spaces, try the last word (most likely the intended one)
        if cleaned.contains(" ") {
            let lastWord = String(cleaned.split(separator: " ").last ?? "")
            if !lastWord.isEmpty {
                return fetchSynonyms(for: lastWord)
            }
        }

        return []
    }

    // MARK: - Private

    private func lookupResults(for key: String) -> [Synonym]? {
        guard let meanings = thesaurus[key] else { return nil }

        var seen = Set<String>()
        var results: [Synonym] = []

        for group in meanings {
            for syn in group where syn != key {
                if seen.insert(syn).inserted {
                    results.append(Synonym(word: syn))
                }
            }
        }

        return results.isEmpty ? nil : results
    }

    /// Clean a raw captured word: trim, lowercase, strip punctuation
    private func cleanWord(_ word: String) -> String {
        var result = word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Strip leading/trailing punctuation
        let punctuation = CharacterSet.punctuationCharacters
            .union(.symbols)
            .union(CharacterSet(charactersIn: "\u{00AB}\u{00BB}\u{201C}\u{201D}\u{2018}\u{2019}\u{2026}\u{2014}\u{2013}"))

        // Strip from start
        while let first = result.unicodeScalars.first, punctuation.contains(first) {
            result = String(result.dropFirst())
        }
        // Strip from end
        while let last = result.unicodeScalars.last, punctuation.contains(last) {
            result = String(result.dropLast())
        }

        return result
    }

    /// Remove all diacritics/accents from a string: "café" -> "cafe"
    private func stripAccents(_ string: String) -> String {
        string.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr"))
    }

    private func buildStrippedIndex() {
        for headword in thesaurus.keys {
            let stripped = stripAccents(headword)
            if stripped != headword {
                strippedIndex[stripped, default: []].append(headword)
            }
        }
    }

    private func loadThesaurus() {
        guard let url = Bundle.main.url(forResource: "thes_fr", withExtension: "dat") else {
            slog("ERROR: thes_fr.dat not found in bundle")
            return
        }
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            slog("ERROR: failed to read thes_fr.dat")
            return
        }

        let lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return }

        var i = 1 // Skip encoding line (UTF-8)
        while i < lines.count {
            let entryLine = lines[i]
            let entryParts = entryLine.split(separator: "|", maxSplits: 1)
            guard entryParts.count == 2, let meaningCount = Int(entryParts[1]) else {
                i += 1
                continue
            }

            let headword = String(entryParts[0]).lowercased()
            var meanings: [[String]] = []

            for j in 1...meaningCount {
                let lineIndex = i + j
                guard lineIndex < lines.count else { break }

                let meaningLine = lines[lineIndex]
                var synonyms = meaningLine.split(separator: "|").map { String($0) }

                // Remove the part-of-speech tag (first element, e.g. "(Nom)")
                if let first = synonyms.first, first.hasPrefix("(") {
                    synonyms.removeFirst()
                }

                if !synonyms.isEmpty {
                    meanings.append(synonyms)
                }
            }

            if !meanings.isEmpty {
                thesaurus[headword] = meanings
            }

            i += 1 + meaningCount
        }
    }
}
