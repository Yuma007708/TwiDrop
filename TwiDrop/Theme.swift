import SwiftUI

/// アプリ全体の配色と部品。ダーク × アンバーの 1 アクセント構成。
enum Theme {
    static let background = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x16 / 255)
    static let surface = Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x22 / 255)
    static let surfaceRaised = Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x30 / 255)
    static let text = Color(red: 0xF4 / 255, green: 0xF3 / 255, blue: 0xF0 / 255)
    static let muted = Color(red: 0x9A / 255, green: 0x9A / 255, blue: 0xA3 / 255)
    static let faint = Color(red: 0x6E / 255, green: 0x6E / 255, blue: 0x78 / 255)
    static let accent = Color(red: 0xF5 / 255, green: 0xB9 / 255, blue: 0x42 / 255)
    static let onAccent = Color(red: 0x1A / 255, green: 0x12 / 255, blue: 0x00 / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x6B / 255, blue: 0x6B / 255)
    static let hairline = Color.white.opacity(0.08)

    static let cornerLarge: CGFloat = 22
    static let cornerMedium: CGFloat = 18
    static let cornerSmall: CGFloat = 12

    /// サムネイルが無いときの動画プレースホルダー。
    static let mediaPlaceholder = RadialGradient(
        colors: [
            Color(red: 0x3B / 255, green: 0x3B / 255, blue: 0x44 / 255),
            Color(red: 0x23 / 255, green: 0x23 / 255, blue: 0x27 / 255),
            Color(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1F / 255),
        ],
        center: .init(x: 0.3, y: 0.2),
        startRadius: 0,
        endRadius: 420
    )
}

/// アンバーの主ボタン。1 画面に 1 つだけ置く。
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.cornerMedium, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 控えめな副ボタン。
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// メディアの上に重ねる小さなバッジ（種別・再生時間）。
struct MediaBadge: View {
    var systemImage: String? = nil
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.background.opacity(0.7), in: Capsule())
        .foregroundStyle(Theme.text)
    }
}

/// 作者のアバター。画像が無ければ名前の 1 文字目。
struct AvatarView: View {
    let name: String
    let url: URL?
    var size: CGFloat = 36

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Color(red: 0x3A / 255, green: 0x4A / 255, blue: 0x6B / 255)
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(Color(red: 0xDC / 255, green: 0xE6 / 255, blue: 0xFA / 255))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

extension Array {
    /// 範囲外なら nil を返す添字。
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
