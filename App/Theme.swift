import SwiftUI

extension Color {
    static let paper = Color(red: 0xEF / 255, green: 0xED / 255, blue: 0xE7 / 255)
    static let paperFace = Color(red: 0xF7 / 255, green: 0xF6 / 255, blue: 0xF2 / 255)
    static let graphite = Color(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1A / 255)
    static let night = Color(red: 0x12 / 255, green: 0x12 / 255, blue: 0x11 / 255)
    static let nightFace = Color(red: 0x1E / 255, green: 0x1E / 255, blue: 0x1D / 255)
    static let signal = Color(red: 1, green: 0x5A / 255, blue: 0x1F / 255)
    static let stone = Color(red: 0x8C / 255, green: 0x8A / 255, blue: 0x84 / 255)
}

extension Font {
    static func tight(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .custom("Inter Tight", size: size).weight(weight)
    }
}

extension AttributedString {
    /// Pulls the characters together without tracking the last one: trailing tracking
    /// shrinks the last glyph's box, and the right edge of it gets clipped.
    static func tight(_ string: String, by tracking: CGFloat) -> AttributedString {
        var text = AttributedString(string)
        if let last = text.characters.indices.last {
            text[text.startIndex..<last].tracking = tracking
        }
        return text
    }
}

/// "twist" plus the little dial dot.
struct Wordmark: View {
    var size: CGFloat = 28
    var color: Color = .graphite

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: size * 0.06) {
            Text("twist")
                .font(.tight(size, .bold))
                .tracking(-size * 0.045)
            ZStack {
                Circle().fill(Color.clear)
                Wedge(degrees: 120).fill(Color.signal)
                Circle().strokeBorder(color, lineWidth: size * 0.03)
            }
            .frame(width: size * 0.2, height: size * 0.2)
            .offset(y: -size * 0.02)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Twist")
    }
}

/// A pie slice from 12 o'clock, clockwise.
struct Wedge: Shape {
    var degrees: Double
    var animatableData: Double {
        get { degrees }
        set { degrees = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard degrees > 0.01 else { return p }
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: min(rect.width, rect.height) / 2,
                 startAngle: .degrees(-90), endAngle: .degrees(-90 + min(degrees, 359.99)), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct PillButton: View {
    var title: String
    var fill: Color = .graphite
    var text: Color = .paper
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.tight(18, .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(fill, in: Capsule())
                .foregroundStyle(text)
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
