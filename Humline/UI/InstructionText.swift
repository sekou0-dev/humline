import SwiftUI

/// Instruction copy that must wrap in full — never scale down or clip mid-sentence.
struct InstructionText: View {
    var text: String
    var font: Font = .body
    var color: Color = .secondary
    var alignment: TextAlignment = .center

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                maxWidth: .infinity,
                alignment: alignment == .leading ? .leading : .center
            )
    }
}
