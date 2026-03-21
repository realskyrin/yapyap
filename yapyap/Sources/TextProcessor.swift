import Foundation

enum TextProcessor {
    private static let punctuationChars = CharacterSet(charactersIn: "，。！？、；：\u{201C}\u{201D}\u{2018}\u{2019}（）《》【】\u{2026}\u{2014},.!?;:")

    static func process(_ text: String) -> String {
        let settings = SettingsStore.shared
        var result = text

        // Punctuation processing
        switch settings.punctuationMode {
        case .spaceReplace:
            result = replacePunctuationWithSpaces(result)
        case .removeTrailing:
            result = removeTrailingPunctuation(result)
        case .keepAll:
            break
        }

        // English/number spacing
        switch settings.englishSpacingMode {
        case .noSpaces:
            result = removeSpacesAroundNonCJK(result)
        case .addSpaces:
            result = addSpacesAroundNonCJK(result)
        }

        return result
    }

    private static func replacePunctuationWithSpaces(_ text: String) -> String {
        var result = ""
        for char in text {
            if char.unicodeScalars.allSatisfy({ punctuationChars.contains($0) }) {
                result.append(" ")
            } else {
                result.append(char)
            }
        }
        // Collapse multiple consecutive spaces into one
        return result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }

    private static func removeTrailingPunctuation(_ text: String) -> String {
        var result = text
        while let last = result.last,
              last.unicodeScalars.allSatisfy({ punctuationChars.contains($0) }) {
            result.removeLast()
        }
        return result
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return (v >= 0x4E00 && v <= 0x9FFF)    // CJK Unified
            || (v >= 0x3400 && v <= 0x4DBF)    // CJK Extension A
            || (v >= 0x3000 && v <= 0x303F)    // CJK Symbols
            || (v >= 0xFF00 && v <= 0xFFEF)    // Fullwidth Forms
            || (v >= 0x2E80 && v <= 0x2EFF)    // CJK Radicals
            || punctuationChars.contains(scalar)
    }

    private static func removeSpacesAroundNonCJK(_ text: String) -> String {
        // Remove spaces that sit between CJK and non-CJK characters
        let chars = Array(text)
        var result = ""
        for (i, char) in chars.enumerated() {
            if char == " " {
                let prev = i > 0 ? chars[i - 1] : nil
                let next = i + 1 < chars.count ? chars[i + 1] : nil
                let prevIsCJK = prev.map { $0.unicodeScalars.contains(where: isCJK) } ?? false
                let nextIsCJK = next.map { $0.unicodeScalars.contains(where: isCJK) } ?? false
                // Drop space if it's between CJK and non-CJK (either direction)
                if (prevIsCJK && !nextIsCJK && next != nil) || (!prevIsCJK && nextIsCJK && prev != nil) {
                    continue
                }
            }
            result.append(char)
        }
        return result
    }

    private static func addSpacesAroundNonCJK(_ text: String) -> String {
        let chars = Array(text)
        var result = ""
        for (i, char) in chars.enumerated() {
            if i > 0 {
                let prev = chars[i - 1]
                let prevIsCJK = prev.unicodeScalars.contains(where: isCJK) && prev != " "
                let currIsCJK = char.unicodeScalars.contains(where: isCJK) && char != " "
                // Add space at CJK ↔ non-CJK boundary (skip if already a space)
                if prevIsCJK != currIsCJK && prev != " " && char != " " {
                    result.append(" ")
                }
            }
            result.append(char)
        }
        return result
    }
}
