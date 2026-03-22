import SwiftUI

// MARK: - SFTPSortColumn

/// Column used for sorting the SFTP file list.
enum SFTPSortColumn {
    case name
    case size
    case date
}

// MARK: - SFTPPanelView

/// Top-level SFTP panel view: toolbar, breadcrumb bar, file list, and transfer footer.
///
/// Receives an `SFTPBrowserService` and renders the full panel UI including
/// a toolbar upload button, breadcrumb navigation, loading indicator, sortable file list,
/// drag-drop target overlay, and non-blocking transfer progress footer.
struct SFTPPanelView: View {

    let service: SFTPBrowserService

    @State private var sortColumn: SFTPSortColumn = .name
    @State private var sortAscending: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar strip with Upload button
            uploadToolbar

            Divider()

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
                mainFileArea
            }

            // Non-blocking transfer progress footer
            SFTPTransferFooter(service: service)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        // Toggle hidden dotfiles with Cmd+Shift+.
        .background(
            Button(action: { service.showHidden.toggle() }, label: { EmptyView() })
                .keyboardShortcut(KeyEquivalent("."), modifiers: [.command, .shift])
        )
    }

    // MARK: - Upload toolbar

    @ViewBuilder
    private var uploadToolbar: some View {
        HStack(spacing: 8) {
            Button {
                openUploadPanel()
            } label: {
                Label("Upload", systemImage: "arrow.up.to.line")
            }
            .buttonStyle(.borderless)
            .help("Upload files to the current remote directory")

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Main file area with drop target overlay

    @ViewBuilder
    private var mainFileArea: some View {
        ZStack {
            SFTPFileListView(
                service: service,
                sortColumn: $sortColumn,
                sortAscending: $sortAscending
            )

            // Invisible NSDraggingDestination overlay for Finder drag-and-drop.
            // Uses .allowsHitTesting(false) so list clicks are not intercepted.
            SFTPDropTargetView(service: service)
                .allowsHitTesting(false)
                .opacity(0.001)
        }
    }

    // MARK: - Upload via NSOpenPanel

    private func openUploadPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Choose files or folders to upload to \(service.currentPath)"
        panel.prompt = "Upload"
        if panel.runModal() == .OK {
            let targetPath = service.currentPath
            for url in panel.urls {
                Task {
                    try? await service.upload(localURL: url, toRemotePath: targetPath)
                }
            }
        }
    }
}
