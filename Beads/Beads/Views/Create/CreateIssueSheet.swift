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
        Form {
            Section {
                TextField("Title", text: $title)

                Picker("Type", selection: $issueType) {
                    ForEach(IssueType.allCases, id: \.self) { type in
                        Label(type.label, systemImage: type.icon).tag(type)
                    }
                }

                Picker("Priority", selection: $priority) {
                    ForEach(IssuePriority.allCases, id: \.self) { p in
                        Text("\(p.label) — \(p.name)").tag(p)
                    }
                }
            }

            Section("Description") {
                TextEditor(text: $description)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
            }

            Section {
                TextField("Labels (comma separated)", text: $labelText)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("New Issue")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
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
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .frame(width: 520, height: 460)
    }
}
