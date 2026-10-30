import SwiftUI

enum TMStyle {
    static let blue = Color(hex: 0x2C73E8)
    static let blueDark = Color(hex: 0x175FCF)
    static let blueSoft = Color(hex: 0xEAF2FF)
    static let ink = Color(hex: 0x172238)
    static let muted = Color(hex: 0x738096)
    static let line = Color(hex: 0xE4E9F0)
    static let canvas = Color(hex: 0xF7F9FC)
    static let violet = Color(hex: 0x7660D6)
    static let violetSoft = Color(hex: 0xF0EDFF)
    static let green = Color(hex: 0x22A775)
    static let greenSoft = Color(hex: 0xE7F7F1)
    static let orange = Color(hex: 0xE58B30)
    static let orangeSoft = Color(hex: 0xFFF3E5)
    static let red = Color(hex: 0xD9545D)
    static let redSoft = Color(hex: 0xFFEBED)
}
extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}
struct TMCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(TMStyle.line, lineWidth: 1))
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.heavy)).tracking(1.2)
            .foregroundStyle(TMStyle.blue)
    }
}
struct PageTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(TMStyle.ink)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(TMStyle.muted) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
    }
}
struct MetricTile: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    var tint: Color = TMStyle.blue
    var body: some View {
        TMCard {
            HStack {
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
                    .frame(width: 40, height: 40).background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 0)
            }
            Text(value).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(TMStyle.ink)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(TMStyle.ink)
            Text(detail).font(.caption).foregroundStyle(TMStyle.muted)
        }
    }
}
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .foregroundStyle(.white).background(TMStyle.blue, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityHint("Activates this action")
    }
}
struct StatusPill: View {
    let text: String
    var color: Color = TMStyle.green
    var body: some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.10), in: Capsule())
            .accessibilityLabel(text)
    }
}
