import Foundation

enum ArabiziTransliterator {
    private static let phrases: [String: String] = [
        "marhaba": "مرحبا",
        "ahlan": "اهلا",
        "salam": "سلام",
        "kifak": "كيفك",
        "kifik": "كيفك",
        "kifkon": "كيفكن",
        "shu": "شو",
        "sho": "شو",
        "shou": "شو",
        "lesh": "ليش",
        "leish": "ليش",
        "mnih": "منيح",
        "mni7": "منيح",
        "tamam": "تمام",
        "yalla": "يلا",
        "habibi": "حبيبي",
        "habibti": "حبيبتي",
        "merci": "مرسي",
        "hayda": "هيدا",
        "hayde": "هيدي",
        "halla2": "هلأ",
        "hala2": "هلأ",
        "inshallah": "انشالله",
        "wallah": "والله",
        "ma3": "مع",
        "3am": "عم",
        "baddi": "بدي",
        "badde": "بدي",
        "badak": "بدك",
        "badik": "بدك",
        "fi": "في",
        "mafi": "ما في"
    ]

    private static let tokens: [(String, String)] = [
        ("allah", "الله"),
        ("kh", "خ"),
        ("sh", "ش"),
        ("ch", "تش"),
        ("th", "ث"),
        ("dh", "ذ"),
        ("gh", "غ"),
        ("aa", "ا"),
        ("ee", "ي"),
        ("ii", "ي"),
        ("oo", "و"),
        ("ou", "و"),
        ("ei", "ي"),
        ("ai", "ي"),
        ("2", "ء"),
        ("3'", "غ"),
        ("3", "ع"),
        ("5", "خ"),
        ("6'", "ظ"),
        ("6", "ط"),
        ("7'", "خ"),
        ("7", "ح"),
        ("8", "ق"),
        ("9'", "ض"),
        ("9", "ص"),
        ("a", "ا"),
        ("b", "ب"),
        ("c", "ك"),
        ("d", "د"),
        ("e", ""),
        ("f", "ف"),
        ("g", "ج"),
        ("h", "ه"),
        ("i", "ي"),
        ("j", "ج"),
        ("k", "ك"),
        ("l", "ل"),
        ("m", "م"),
        ("n", "ن"),
        ("o", "و"),
        ("p", "ب"),
        ("q", "ق"),
        ("r", "ر"),
        ("s", "س"),
        ("t", "ت"),
        ("u", "و"),
        ("v", "ف"),
        ("w", "و"),
        ("x", "كس"),
        ("y", "ي"),
        ("z", "ز")
    ]

    static func convert(_ input: String) -> String {
        input
            .split(omittingEmptySubsequences: false, whereSeparator: { $0.isWhitespace })
            .map { convertWord(String($0)) }
            .joined(separator: " ")
    }

    private static func convertWord(_ word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
        let leadingCount = word.prefix(while: { $0.isPunctuation }).count
        let trailingCount = word.reversed().prefix(while: { $0.isPunctuation }).count
        let leading = String(word.prefix(leadingCount))
        let trailing = String(word.suffix(trailingCount))

        guard !trimmed.isEmpty else {
            return word
        }

        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "-", with: "")

        if let phrase = phrases[normalized] {
            return leading + phrase + trailing
        }

        return leading + transliterate(normalized) + trailing
    }

    private static func transliterate(_ word: String) -> String {
        var output = ""
        var index = word.startIndex

        while index < word.endIndex {
            var matched = false
            let suffix = word[index...]

            for (latin, arabic) in tokens {
                if suffix.hasPrefix(latin) {
                    output += arabic
                    index = word.index(index, offsetBy: latin.count)
                    matched = true
                    break
                }
            }

            if !matched {
                output.append(word[index])
                index = word.index(after: index)
            }
        }

        return tidy(output)
    }

    private static func tidy(_ text: String) -> String {
        var result = text
        while result.contains("اا") {
            result = result.replacingOccurrences(of: "اا", with: "ا")
        }
        while result.contains("يي") {
            result = result.replacingOccurrences(of: "يي", with: "ي")
        }
        while result.contains("وو") {
            result = result.replacingOccurrences(of: "وو", with: "و")
        }
        return result
    }
}
