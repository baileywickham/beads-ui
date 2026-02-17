import SwiftUI

struct IssueCommentsView: View {
    let comments: [Comment]
    let onAdd: (String) -> Void

    @State private var newComment = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .padding(8)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            HStack {
                TextField("Add a comment...", text: $newComment, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)

                Button {
                    guard !newComment.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onAdd(newComment)
                    newComment = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(8)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}
