import SwiftUI
import UIKit

enum Palette {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.10, blue: 0.15, alpha: 1)
            : UIColor(red: 1.00, green: 0.976, blue: 0.949, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.19, green: 0.17, blue: 0.23, alpha: 1)
            : .white
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.98, green: 0.93, blue: 0.90, alpha: 1)
            : UIColor(red: 0.26, green: 0.20, blue: 0.23, alpha: 1)
    })
    static let coral = Color(red: 1.00, green: 0.43, blue: 0.39)
    static let peach = Color(red: 1.00, green: 0.82, blue: 0.66)
    static let lilac = Color(red: 0.83, green: 0.73, blue: 0.98)
    static let mint = Color(red: 0.66, green: 0.88, blue: 0.78)
    static let yellow = Color(red: 1.00, green: 0.88, blue: 0.57)
}

struct WarmBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.background
                Circle().fill(Palette.peach.opacity(0.28))
                    .frame(width: 310, height: 310)
                    .position(x: geometry.size.width + 70, y: 90)
                Circle().fill(Palette.lilac.opacity(0.18))
                    .frame(width: 250, height: 250)
                    .position(x: -90, y: geometry.size.height * 0.58)
                Circle().fill(Palette.mint.opacity(0.18))
                    .frame(width: 190, height: 190)
                    .position(x: geometry.size.width + 50, y: geometry.size.height - 40)
            }
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: String) {
        let value = Int(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0xFFB39E
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

struct CozyCard<Content: View>: View {
    var color: Color
    var content: Content

    init(color: Color = Palette.surface, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Palette.ink.opacity(0.055)))
    }
}

struct PillButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Palette.coral, in: Capsule())
        }
        .buttonStyle(SoftPressStyle())
    }
}

struct SoftPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

struct CelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst = false
    private let symbols = ["✨", "🌼", "💛", "⭐️", "🌱", "🎉"]

    var body: some View {
        ZStack {
            ForEach(symbols.indices, id: \.self) { index in
                Text(symbols[index])
                    .font(.system(size: 29))
                    .offset(x: burst ? CGFloat(cos(Double(index) * .pi / 3) * 125) : 0,
                            y: burst ? CGFloat(sin(Double(index) * .pi / 3) * 100) : 0)
                    .opacity(burst ? 0 : 1)
            }
            Text("Harikasın! 🎉").font(.largeTitle.bold())
                .scaleEffect(burst ? 1.05 : 0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.7)) { burst = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Harikasın, birikimin eklendi")
    }
}

struct MoneyInput: View {
    let title: String
    @Binding var text: String
    let currency: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink.opacity(0.7))
            HStack {
                TextField("0", text: $text).keyboardType(.decimalPad)
                Text(currency).foregroundStyle(Palette.ink.opacity(0.55))
            }
            .font(.title3.weight(.bold))
            .padding(15)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

enum InputAmount {
    static func minor(_ text: String) -> Int64? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), amount > 0 else { return nil }
        return Money.minor(amount)
    }
}
