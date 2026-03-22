import SwiftUI

// MARK: - SFTPSortColumn

/// Column used for sorting the SFTP file list.
enum SFTPSortColumn {
    case name
    case size
    case date
}

// MARK: - SFTPPanelView

/// Top-level SFTP panel view: breadcrumb bar + file list (or loading/connecting state).
///
/// Receives an `SFTPBrowserService` and renders the full panel UI including
/// breadcrumb navigation, loading indicator, and the sortable file list.
struct SFTPPanelView: View {

    let service: SFTPBrowserService

    @State private var sortColumn: SFTPSortColumn = .name
    @State private var sortAscending: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb navigation bar
            SFTPBreadcrumbBar(currentPath: service.currentPath) { path in
                Task {
                    try? await service.listDirectory(path: path)
                }
            }

            Divider()

            // Main content area
            if service.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !service.isConnected {
                Text("Connecting...")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SFTPFileListView(
                    service: service,
                    sortColumn: $sortColumn,
                    sortAscending: $sortAscending
                )
            }

            Divider()

            // Transfer footer — Plan 03-05 implements the real footer
            Text("")
                .frame(height: 0)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        // Toggle hidden dotfiles with Cmd+Shift+.
        .background(
            Button(action: { service.showHidden.toggle() }, label: { EmptyView() })
                .keyboardShortcut(KeyEquivalent("."), modifiers: [.command, .shift])
        )
    }
}
