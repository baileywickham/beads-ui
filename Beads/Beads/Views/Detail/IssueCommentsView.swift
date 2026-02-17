import SwiftUI

struct IssueCommentsView: View {
    let comments: [Comment]
    let onAdd: (String) -> Void

    @State private var newComment = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Comments (\(comments.count))")
                .font(.headline)

            ForEach(comments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.author)
                            .font(.callout)
                            .fontWeight(.medium)
                        Spacer()
                        RelativeTimeText(date: comment.createdAt)
                    }
                    MarkdownView(content: comment.text)
                        .font(.callout)
                }
                .padding(10)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(alignment: .bottom) {
                TextField("Add a comment...", text: $newComment, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isInputFocused)

                Button {
                    guard !newComment.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onAdd(newComment)
                        newComment = ""
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(newComment.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.borderless)
                .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isInputFocused ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
                    .fill(.background)
            )
        }
    }
}
