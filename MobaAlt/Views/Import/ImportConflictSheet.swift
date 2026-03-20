import SwiftUI

// MARK: - Conflict Resolution

enum ConflictResolution: String, CaseIterable {
    case overwrite = "Overwrite"
    case rename    = "Rename (auto-suffix)"
    case skip      = "Skip"
}

// MARK: - Import Conflict Sheet

/// Shows a list of naming conflicts and lets the user choose how to resolve each one.
struct ImportConflictSheet: View {
    let conflicts: [SessionConflict]
    @Binding var resolutions: [UUID: ConflictResolution]
    var onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Resolve Import Conflicts", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.bar)

            Divider()

            // Apply to All
            HStack {
                Text("Apply to all:")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                    Button(resolution.rawValue) {
                        applyToAll(resolution: resolution)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Conflict list
            List(conflicts, id: \.incoming.id) { conflict in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conflict.incoming.name)
                            .fontWeight(.medium)
                        Text(conflict.incoming.protocolConfig.hostname)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: Binding(
                        get: { resolutions[conflict.incoming.id] ?? .overwrite },
                        set: { resolutions[conflict.incoming.id] = $0 }
                    )) {
                        ForEach(ConflictResolution.allCases, id: \.self) { res in
                            Text(res.rawValue).tag(res)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()

            // Footer
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 400)
        .onAppear {
            // Initialize default resolutions for all conflicts
            for conflict in conflicts where resolutions[conflict.incoming.id] == nil {
                resolutions[conflict.incoming.id] = .overwrite
            }
        }
    }

    private func applyToAll(resolution: ConflictResolution) {
        for conflict in conflicts {
            resolutions[conflict.incoming.id] = resolution
        }
    }
}
