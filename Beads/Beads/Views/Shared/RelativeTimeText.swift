import SwiftUI

struct RelativeTimeText: View {
    let date: Date

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        Text(Self.formatter.localizedString(for: date, relativeTo: Date()))
            .foregroundStyle(.secondary)
            .font(.caption)
    }
}
