import Foundation

enum MailHeaderEncoder {
    static func encode(_ value: String) -> String {
        let sanitizedValue = value
            .replacing("\r", with: "")
            .replacing("\n", with: "")

        guard sanitizedValue.contains(where: { !$0.isASCII }) else {
            return sanitizedValue
        }

        return encodedWords(for: sanitizedValue).joined(separator: " ")
    }

    private static func encodedWords(for value: String) -> [String] {
        let maxChunkSize = 45
        var words: [String] = []
        var current = ""
        var currentByteCount = 0

        for character in value {
            let byteCount = character.utf8.count

            if currentByteCount + byteCount > maxChunkSize, !current.isEmpty {
                words.append(encodedWord(for: current))
                current = ""
                currentByteCount = 0
            }

            current.append(character)
            currentByteCount += byteCount
        }

        if !current.isEmpty {
            words.append(encodedWord(for: current))
        }

        return words
    }

    private static func encodedWord(for value: String) -> String {
        let encodedValue = Data(value.utf8).base64EncodedString()

        return "=?UTF-8?B?\(encodedValue)?="
    }
}
