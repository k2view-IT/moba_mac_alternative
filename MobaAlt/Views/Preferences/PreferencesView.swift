import SwiftUI

struct PreferencesView: View {
    @AppStorage("sidebarDensity") private var density: SidebarDensity = .comfortable
    @AppStorage("sftpDefaultPosition") private var sftpDefaultPosition: SFTPPanelPosition = .left

    var body: some View {
        Form {
            Section("Sidebar") {
                Picker("Density", selection: $density) {
                    Text("Compact").tag(SidebarDensity.compact)
                    Text("Comfortable").tag(SidebarDensity.comfortable)
                }
                .pickerStyle(.segmented)

                LabeledContent("Toggle Shortcut") {
                    Text("⌘⇧L")
                        .foregroundStyle(.secondary)
                }
            }

            Section("SFTP Panel") {
                Picker("Default Panel Position", selection: $sftpDefaultPosition) {
                    ForEach(SFTPPanelPosition.allCases, id: \.self) { pos in
                        Text(pos.displayName).tag(pos)
                    }
                }
                .pickerStyle(.segmented)

                Text("Can be overridden per-session using the toolbar button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 280)
        .navigationTitle("Preferences")
    }
}
