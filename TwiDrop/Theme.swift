import SwiftUI

/// アプリ全体の配色と部品。白ベースにインディゴ 1 色。
enum Theme {
    static let background = Color(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xFA / 255)
    static let surface = Color.white
    static let tint = Color(red: 0xE6 / 255, green: 0xE6 / 255, blue: 0xF2 / 255)
    static let tintStrong = Color(red: 0xC9 / 255, green: 0xC9 / 255, blue: 0xF0 / 255)
    static let text = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x2E / 255)
    static let muted = Color(red: 0x63 / 255, green: 0x63 / 255, blue: 0x7F / 255)
    static let accent = Color(red: 0x2B / 255, green: 0x2E / 255, blue: 0xD9 / 255)
    static let onAccent = Color.white
    static let danger = Color(red: 0xD9 / 255, green: 0x2B / 255, blue: 0x4C / 255)

    static let cornerCard: CGFloat = 24
    static let cornerPill: CGFloat = 28

    /// サムネイルが無いときのメディアのプレースホルダー。
    static let mediaPlaceholder = LinearGradient(
        colors: [tint, tintStrong],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// カードの影。インディゴをほんの少し含める。
    static let cardShadow = accent.opacity(0.08)
}

/// インディゴの主ボタン。1 画面に 1 つだけ置く。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            // 無効時は透明度ではなく専用の色にして、文字が読める状態を保つ。
            .foregroundStyle(isEnabled ? Theme.onAccent : Theme.accent)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(isEnabled ? Theme.accent : Theme.tintStrong, in: Capsule())
            .shadow(
                color: Theme.accent.opacity(!isEnabled ? 0 : (configuration.isPressed ? 0.15 : 0.28)),
                radius: 12, y: 8
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 白い副ボタン。
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.tint, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// メディアの上に重ねる小さなバッジ（種別・再生時間）。
struct MediaBadge: View {
    var systemImage: String? = nil
    let text: String
    var highlighted = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text).font(.caption.weight(.heavy)).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(highlighted ? Theme.accent : Theme.text, in: Capsule())
        .foregroundStyle(.white)
    }
}

/// 作者のアバター。画像が無ければ名前の 1 文字目。
struct AvatarView: View {
    let name: String
    let url: URL?
    var size: CGFloat = 38

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Theme.tint
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .heavy))
                    .foregroundStyle(Theme.accent)
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
