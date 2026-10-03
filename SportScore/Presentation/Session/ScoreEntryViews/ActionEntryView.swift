import SwiftUI

struct EntryAction: Identifiable {
    let id = UUID()
    let title: String
    var systemImage: String? = nil
    var tint: Color? = nil
    var isProminent: Bool = false
    let entry: () -> ScoreEntry
}

/// A column of outcome buttons for result-based games (chess, pool racks, croquet hoops…).
struct ActionEntryView: View {
    let actions: [EntryAction]
    let onSubmit: (ScoreEntry) -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(actions) { action in
                if action.isProminent {
                    button(action).buttonStyle(.borderedProminent)
                } else {
                    button(action).buttonStyle(.bordered)
                }
            }
        }
    }

    private func button(_ action: EntryAction) -> some View {
        Button {
            onSubmit(action.entry())
        } label: {
            Group {
                if let image = action.systemImage {
                    Label(action.title, systemImage: image)
                } else {
                    Text(action.title)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .tint(action.tint)
    }
}
