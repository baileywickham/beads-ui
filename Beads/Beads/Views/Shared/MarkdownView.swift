import MarkdownUI
import SwiftUI

struct MarkdownView: View {
    let content: String

    var body: some View {
        if content.isEmpty {
            Text("No content")
                .foregroundStyle(.tertiary)
                .italic()
        } else {
            Markdown(content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
