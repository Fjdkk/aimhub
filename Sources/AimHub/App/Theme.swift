import SwiftUI

enum Theme {
    static let bg = Color(red: 0.043, green: 0.055, blue: 0.078)
    static let card = Color(red: 0.078, green: 0.098, blue: 0.149)
    static let card2 = Color(red: 0.102, green: 0.129, blue: 0.188)
    static let border = Color(red: 0.137, green: 0.173, blue: 0.239)
    static let text = Color(red: 0.910, green: 0.925, blue: 0.957)
    static let muted = Color(red: 0.545, green: 0.584, blue: 0.655)
    static let accent = Color(red: 0.0, green: 0.831, blue: 1.0)
    static let accent2 = Color(red: 0.541, green: 0.361, blue: 1.0)
    static let green = Color(red: 0.180, green: 0.800, blue: 0.443)
    static let red = Color(red: 0.906, green: 0.298, blue: 0.235)
    static let orange = Color(red: 1.0, green: 0.624, blue: 0.263)

    static func gradient() -> LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View {
        modifier(CardModifier(padding: padding))
    }

    func primaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gradient())
            .foregroundColor(.white)
            .cornerRadius(14)
            .font(.system(size: 16, weight: .bold))
            .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 4)
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .kerning(0.5)
            .foregroundColor(Theme.muted)
            .padding(.horizontal, 4)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }
}