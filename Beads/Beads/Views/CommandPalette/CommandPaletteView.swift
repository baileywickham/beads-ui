import SwiftUI

struct CommandPaletteView: View {
    @Bindable var paletteState: CommandPaletteState
    let onSelect: (Issue) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search issues...", text: Binding(
                    get: { paletteState.query },
                    set: {
                        paletteState.query = $0
                        paletteState.search()
                    }
                ))
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit {
                    if let issue = paletteState.selectedIssue {
                        onSelect(issue)
                        paletteState.toggle()
                    }
                }

                Button {
                    paletteState.toggle()
                } label: {
                    Text("esc")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            if !paletteState.results.isEmpty {
                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(paletteState.results.enumerated()), id: \.element.id) { index, issue in
                            Button {
                                onSelect(issue)
                                paletteState.toggle()
                            } label: {
                                HStack(spacing: 8) {
                                    PriorityIndicator(priority: issue.priority)
                                    StatusChip(status: issue.status)
                                    Text(issue.title)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(issue.id)
                                        .font(.caption)
                                        .monospaced()
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(index == paletteState.selectedIndex ? Color.accentColor.opacity(0.1) : .clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
        .frame(width: 600)
        .onKeyPress(.upArrow) {
            paletteState.moveUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            paletteState.moveDown()
            return .handled
        }
        .onKeyPress(.escape) {
            paletteState.toggle()
            return .handled
        }
    }
}
