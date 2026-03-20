import SwiftUI

struct PreferencesView: View {
    @AppStorage("sidebarDensity") private var density: SidebarDensity = .comfortable

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
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
        .navigationTitle("Preferences")
    }
}
