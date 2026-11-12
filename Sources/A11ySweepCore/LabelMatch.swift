import Foundation

public enum LabelMatch {
    public static func labelContainsVisibleText(label: String, visibleText: String) -> Bool {
        let visible = words(in: visibleText)
        guard visible.contains(where: { $0.unicodeScalars.contains(where: CharacterSet.letters.contains) }) else {
            return true
        }
        let labelWords = words(in: label)
        var position = labelWords.startIndex
        for word in visible where word.count >= 2 {
            guard let found = labelWords[position...].firstIndex(of: word) else { return false }
            position = labelWords.index(after: found)
        }
        return true
    }

    private static func words(in string: String) -> [String] {
        let folded = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let cleaned = String(folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        })
        return cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}
