import SwiftUI

struct IssueMarkdownSection: View {
    let title: String
    let content: String
    let onSave: (String) -> Void

    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    if isEditing {
                        onSave(editText)
                        isEditing = false
                    } else {
                        editText = content
                        isEditing = true
                    }
                } label: {
                    Text(isEditing ? "Save" : "Edit")
                        .font(.caption)
                }
                .buttonStyle(.link)

                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }

            if isEditing {
                TextEditor(text: $editText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                MarkdownView(content: content)
            }
        }
    }
}
