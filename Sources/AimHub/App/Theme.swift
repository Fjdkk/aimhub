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

    // MARK: - Typography chuẩn iOS (SF Pro)
    // Font hệ thống SwiftUI mặc định đã là SF Pro; các helper dưới đây
    // chuẩn hoá phân cấp chữ dùng thống nhất toàn app.

    /// Heading: lớn, Semibold/Bold.
    static func heading(_ size: CGFloat = 22, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Label: Medium/Semibold.
    static func label(_ size: CGFloat = 15, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Description/body: Regular.
    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Status: Medium/Semibold, dùng cho dòng trạng thái.
    static func status(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Giữ lại cho code cũ gọi Theme.font(...) — tương đương .system SF Pro.
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 14
    /// Bật highlight mép trên (cảm giác nổi khối), tắt cho card lồng nhau.
    var elevated = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                // Nền tối trong suốt nhẹ (glassmorphism tinh tế)
                LinearGradient(
                    colors: [Theme.card, Theme.card.opacity(0.92)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        // Viền trắng alpha thấp + viền gốc — chiều sâu kiểu iOS
                        LinearGradient(
                            colors: [.white.opacity(0.10), Theme.border.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(elevated ? 0.22 : 0.12), radius: 12, y: 5)
    }
}

extension View {
    func card(padding: CGFloat = 14, elevated: Bool = true) -> some View {
        modifier(CardModifier(padding: padding, elevated: elevated))
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

    /// Hiệu ứng bấm nút co giãn nhẹ theo chuẩn iOS (kết hợp với Button).
    func pressable(scale: CGFloat = 0.97) -> some View {
        modifier(PressableModifier(scale: scale))
    }
}

/// ButtonStyle phản hồi cảm giác bấm: co nhẹ + mờ nhẹ khi press.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var opacity: Double = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

private struct PressableModifier: ViewModifier {
    var scale: CGFloat
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? scale : 1)
            .opacity(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: pressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { value in
                pressed = value
            }, perform: {})
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

// MARK: - Glass Light Sweep (hiệu ứng ánh sáng kính lướt ngang)

/// Dải ánh sáng trắng mờ chạy chậm từ trái sang phải, lặp theo chu kỳ,
/// bị giới hạn (mask) theo hình dạng của view áp dụng — ví dụ logo hay ô nhập.
/// Ánh sáng dùng blendMode(.plusLighter) nên chỉ làm nổi chi tiết, không chói.
struct LightSweepModifier: ViewModifier {
    /// Thời gian 1 lần quét (giây) — chậm và mượt.
    var duration: Double = 3.6
    /// Thời gian chờ giữa 2 lần quét (giây).
    var pause: Double = 1.8
    /// Độ sáng dải đèn (0...1).
    var intensity: Double = 0.32

    @State private var phase: CGFloat = -1.3

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear,
                                 .white.opacity(intensity * 0.35),
                                 .white.opacity(intensity),
                                 .white.opacity(intensity * 0.35),
                                 .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.55)
                    .offset(x: geo.size.width * phase)
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
            )
            .mask(content)
            .onAppear {
                sweep()
            }
    }

    private func sweep() {
        withAnimation(.easeInOut(duration: duration).delay(pause)) {
            phase = 1.9
        }
        // Sau khi quét xong, quay về vị trí đầu (vô hình) rồi lặp lại chu kỳ.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + pause + 0.1) {
            phase = -1.3
            sweep()
        }
    }
}

extension View {
    /// Áp hiệu ứng Glass Light Sweep lên view (logo, card login...).
    func lightSweep(duration: Double = 3.6, pause: Double = 1.8, intensity: Double = 0.32) -> some View {
        modifier(LightSweepModifier(duration: duration, pause: pause, intensity: intensity))
    }
}
