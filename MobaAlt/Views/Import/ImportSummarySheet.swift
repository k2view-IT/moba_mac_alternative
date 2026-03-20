import SwiftUI

// MARK: - Import Summary Sheet

/// Simple post-import summary showing counts of imported, created, and skipped items.
struct ImportSummarySheet: View {
    let stats: ImportStats
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Import Complete")
                .font(.title2)
                .fontWeight(.semibold)

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                StatRow(label: "Sessions imported", value: stats.sessionsImported)
                StatRow(label: "Folders created", value: stats.foldersCreated)
                if stats.sessionsSkipped > 0 {
                    StatRow(label: "Sessions skipped", value: stats.sessionsSkipped)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 320)
    }
}

// MARK: - Stat Row

private struct StatRow: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}
