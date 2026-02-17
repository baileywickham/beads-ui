import SwiftUI

struct TypeIcon: View {
    let type: IssueType

    var body: some View {
        Image(systemName: type.icon)
            .font(.caption)
            .foregroundStyle(type.color)
    }
}
