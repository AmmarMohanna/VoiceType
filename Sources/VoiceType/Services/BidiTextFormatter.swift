import Foundation

enum BidiTextFormatter {
    private static let leftToRightIsolate = "\u{2066}"
    private static let popDirectionalIsolate = "\u{2069}"

    static func prepareMixedArabicEnglish(_ text: String) -> String {
        let spaced = addArabicLatinSpacing(text)
        guard containsArabic(spaced), containsLatin(spaced) else {
            return spaced
        }

        var result = ""
        var latinRun = ""

        func flushLatinRun() {
            guard !latinRun.isEmpty else {
                return
            }

            result += leftToRightIsolate + latinRun + popDirectionalIsolate
            latinRun = ""
        }

        for character in spaced {
            if isLatinRunCharacter(character) {
                latinRun.append(character)
            } else {
                flushLatinRun()
                result.append(character)
            }
        }

        flushLatinRun()
        return result
    }

    private static func addArabicLatinSpacing(_ text: String) -> String {
        var result = ""
        var previous: Character?

        for character in text {
            if let previous,
               shouldInsertSpace(between: previous, and: character) {
                result.append(" ")
            }

            result.append(character)
            previous = character
        }

        return result
    }

    private static func shouldInsertSpace(between first: Character, and second: Character) -> Bool {
        guard !first.isWhitespace,
              !second.isWhitespace,
              !first.isPunctuation,
              !second.isPunctuation else {
            return false
        }

        return (isArabic(first) && containsLatin(second)) || (containsLatin(first) && isArabic(second))
    }

    private static func isLatinRunCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
    }

    private static func containsArabic(_ text: String) -> Bool {
        text.contains { isArabic($0) }
    }

    private static func containsLatin(_ text: String) -> Bool {
        text.contains { containsLatin($0) }
    }

    private static func containsLatin(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            ("A"..."Z").contains(scalar) || ("a"..."z").contains(scalar)
        }
    }

    private static func isArabic(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF,
                 0x0750...0x077F,
                 0x08A0...0x08FF,
                 0xFB50...0xFDFF,
                 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }
}
