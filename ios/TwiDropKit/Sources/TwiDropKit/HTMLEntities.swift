import Foundation

/// ツイート本文に含まれる HTML エンティティを元の文字へ戻す。
///
/// `NSAttributedString` の HTML 読み込みはメインスレッド専用で重いため、
/// API が返す範囲のエンティティだけを自前で処理する。
enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"",
        "apos": "'", "nbsp": "\u{00A0}",
    ]

    static func decode(_ input: String) -> String {
        guard input.contains("&") else { return input }

        var output = ""
        output.reserveCapacity(input.count)
        var remainder = Substring(input)

        while let ampersand = remainder.firstIndex(of: "&") {
            output.append(contentsOf: remainder[remainder.startIndex..<ampersand])
            let afterAmpersand = remainder.index(after: ampersand)

            // エンティティは最大でも `&#x1F600;` 程度の長さしかない。
            let searchLimit = remainder.index(
                afterAmpersand, offsetBy: 10, limitedBy: remainder.endIndex
            ) ?? remainder.endIndex

            guard let semicolon = remainder[afterAmpersand..<searchLimit].firstIndex(of: ";") else {
                output.append("&")
                remainder = remainder[afterAmpersand...]
                continue
            }

            let body = String(remainder[afterAmpersand..<semicolon])
            if let replacement = resolve(body) {
                output.append(replacement)
            } else {
                output.append("&\(body);")
            }
            remainder = remainder[remainder.index(after: semicolon)...]
        }

        output.append(contentsOf: remainder)
        return output
    }

    private static func resolve(_ body: String) -> String? {
        if let named = named[body.lowercased()] {
            return named
        }
        guard body.hasPrefix("#") else { return nil }

        let digits = String(body.dropFirst())
        let scalarValue: UInt32?
        if digits.lowercased().hasPrefix("x") {
            scalarValue = UInt32(digits.dropFirst(), radix: 16)
        } else {
            scalarValue = UInt32(digits, radix: 10)
        }
        guard let scalarValue, let scalar = Unicode.Scalar(scalarValue) else { return nil }
        return String(Character(scalar))
    }
}
