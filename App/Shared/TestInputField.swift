import SwiftUI

/// 키보드 시험용 입력 칸.
struct TestInputField: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool
    var autofocus = false

    var body: some View {
        TextField("여기를 눌러 입력해 보세요", text: $text, axis: .vertical)
            .lineLimit(3...6)
            .focused($isFocused)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1.5)
            }
            .task {
                if autofocus { isFocused = true }
            }
    }
}
