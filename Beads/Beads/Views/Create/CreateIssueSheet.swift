import SwiftUI

struct CreateIssueSheet: View {
    @Bindable var state: ProjectState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var issueType: IssueType = .task
    @State private var priority: IssuePriority = .p2
    @State private var description = ""
    @State private var labelText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Issue")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Picker("Type", selection: $issueType) {
                        ForEach(IssueType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icon).tag(type)
                        }
                    }
                    .frame(maxWidth: 200)

                    Picker("Priority", selection: $priority) {
                        ForEach(IssuePriority.allCases, id: \.self) { p in
                            Text("\(p.label) — \(p.name)").tag(p)
                        }
                    }
                    .frame(maxWidth: 200)
                }

                VStack(alignment: .leading) {
                    Text("Description")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $description)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                TextField("Labels (comma separated)", text: $labelText)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .padding(.horizontal)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Create") {
                    let labels = labelText.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    state.createIssue(
                        title: title, type: issueType, priority: priority,
                        description: description.isEmpty ? nil : description,
                        labels: labels
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 560, height: 480)
    }
}
