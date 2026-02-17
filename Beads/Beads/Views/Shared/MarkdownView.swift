import SwiftUI

struct MarkdownView: View {
    let content: String

    var body: some View {
        if content.isEmpty {
            Text("No content")
                .foregroundStyle(.tertiary)
                .italic()
        } else if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .full)) {
            Text(attributed)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
