import Foundation

/// syndication エンドポイントが要求する `token` クエリの生成。
///
/// 公式の埋め込みスクリプトと同じ手順で、ツイート ID から決定的に導出する。
/// `Double` の精度を使う点も JavaScript の `Number` と揃えてある。
public enum SyndicationToken {
    private static let digits = Array("0123456789abcdefghijklmnopqrstuvwxyz")

    /// ツイート ID に対応するトークンを返す。
    public static func make(for tweetID: String) -> String {
        let numeric = Double(tweetID) ?? 0
        let value = (numeric / 1e15) * Double.pi
        return base36(value)
            .replacingOccurrences(of: "0", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    /// 浮動小数点数を 36 進数表記にする（JS の `Number#toString(36)` 相当）。
    static func base36(_ value: Double, fractionDigits: Int = 20) -> String {
        var integral = Int(value)
        var fraction = value - Double(integral)

        var head = ""
        if integral == 0 {
            head = "0"
        }
        while integral > 0 {
            head = String(digits[integral % 36]) + head
            integral /= 36
        }

        var tail = ""
        for _ in 0..<fractionDigits {
            fraction *= 36
            let digit = Int(fraction)
            tail.append(digits[digit])
            fraction -= Double(digit)
        }
        return "\(head).\(tail)"
    }
}
