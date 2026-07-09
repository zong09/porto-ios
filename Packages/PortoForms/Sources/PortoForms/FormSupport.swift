import SwiftUI
import PortoKit

/// Shared helpers for the form sheets in this package.
enum FormSupport {
    /// Parses a user-typed numeric string, stripping `$`, `฿`, and thousands separators.
    static func parseDouble(_ raw: String) -> Double? {
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "฿", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}

/// Inline error banner shown at the bottom of a form on submit failure.
struct FormErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Cross-platform decimal-friendly text field (iOS gets the decimal pad keyboard).
struct NumericField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = "0.00"

    var body: some View {
        TextField(placeholder, text: $text)
            #if os(iOS)
            .keyboardType(.decimalPad)
            #endif
    }
}
