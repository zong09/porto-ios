import SwiftUI
import PortoKit

// MARK: - Cross-platform card background

public extension Color {
    /// Adaptive card surface color (works on iOS and on the macOS CLI build).
    static var cardBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .underPageBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }
}

// MARK: - Card

/// Standard card container: padded, rounded, subtle background + border.
public struct CardModifier: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

// MARK: - Badge

/// Small pill badge with a tint color.
public struct BadgeModifier: ViewModifier {
    var color: Color
    public func body(content: Content) -> some View {
        content
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

public extension View {
    /// Wrap in the standard card container.
    func card(padding: CGFloat = 14, cornerRadius: CGFloat = 14) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    /// Render as a small tinted pill badge.
    func badge(_ color: Color) -> some View {
        modifier(BadgeModifier(color: color))
    }
}

// MARK: - P/L color helper

public enum PnL {
    /// Green for gains (>= 0), red for losses — taken from the active theme.
    public static func color(_ value: Double, theme: Theme) -> Color {
        value >= 0 ? (theme.greens.first ?? .green) : (theme.reds.first ?? .red)
    }
}
