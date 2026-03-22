import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - SFTPFileRowView

/// NSViewRepresentable wrapper providing NSFilePromiseProvider drag-to-Finder support.
///
/// SwiftUI's `onDrag` cannot deliver files to Finder's sidebar or Desktop — only
/// NSFilePromiseProvider (an AppKit API) supports file-promise drag operations that
/// Finder can accept. This view is used as an invisible overlay in SFTPFileListView.
struct SFTPFileRowView: NSViewRepresentable {

    let item: SFTPItem
    let service: SFTPBrowserService

    func makeNSView(context: Context) -> SFTPDragSourceView {
        SFTPDragSourceView(item: item, service: service)
    }

    func updateNSView(_ nsView: SFTPDragSourceView, context: Context) {
        nsView.remoteFile = item
        nsView.sftpService = service
    }
}

// MARK: - SFTPDragSourceView

/// Invisible NSView subclass that captures mouse drag events to initiate
/// NSFilePromiseProvider drag sessions destined for Finder.
final class SFTPDragSourceView: NSView, NSDraggingSource, NSFilePromiseProviderDelegate {

    var remoteFile: SFTPItem?
    weak var sftpService: SFTPBrowserService?

    init(item: SFTPItem, service: SFTPBrowserService) {
        self.remoteFile = item
        self.sftpService = service
        super.init(frame: .zero)
        // Allow this view to receive mouse-dragged events.
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Mouse drag handling

    override func mouseDragged(with event: NSEvent) {
        guard let file = remoteFile else { return }

        // Create a file-promise provider for Finder drag-out.
        let provider = NSFilePromiseProvider(
            fileType: UTType.data.identifier,
            delegate: self
        )
        provider.userInfo = ["path": file.path, "name": file.name]

        // Build a dragging item with a generic file icon.
        let draggingItem = NSDraggingItem(pasteboardWriter: provider)
        let dragImage = NSWorkspace.shared.icon(forFileType: (file.name as NSString).pathExtension)
        draggingItem.setDraggingFrame(
            NSRect(x: 0, y: 0, width: 32, height: 32),
            contents: dragImage
        )

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    // MARK: - NSDraggingSource

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        return .copy
    }

    // MARK: - NSFilePromiseProviderDelegate

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        fileNameForType fileType: String
    ) -> String {
        return remoteFile?.name ?? "download"
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let file = remoteFile, let service = sftpService else {
            completionHandler(SFTPError.connectionFailed("No file or service available"))
            return
        }

        Task {
            do {
                try await service.download(remotePath: file.path, toLocalURL: url)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
