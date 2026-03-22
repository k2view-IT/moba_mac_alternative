import AppKit
import SwiftUI

// MARK: - SFTPDropTargetView

/// SwiftUI wrapper that places an `SFTPDropTargetNSView` as a full-size invisible overlay
/// over the SFTP file list. This enables Finder-to-panel drag-and-drop using AppKit's
/// `NSDraggingDestination` protocol, which supports cross-application file drops.
///
/// The view is rendered at near-zero opacity (0.001) and with `.allowsHitTesting(false)` so
/// clicks are passed through to the list beneath it. Only drag events are captured.
struct SFTPDropTargetView: NSViewRepresentable {

    let service: SFTPBrowserService

    func makeNSView(context: Context) -> SFTPDropTargetNSView {
        SFTPDropTargetNSView(service: service)
    }

    func updateNSView(_ nsView: SFTPDropTargetNSView, context: Context) {
        nsView.service = service
    }
}

// MARK: - SFTPDropTargetNSView

/// AppKit NSView that acts as a `NSDraggingDestination` for Finder file drops.
///
/// When files are dragged from Finder onto this view, each URL is uploaded to
/// `service.currentPath` via `service.upload()`.
final class SFTPDropTargetNSView: NSView {

    // MARK: - State

    var service: SFTPBrowserService

    /// Whether the drag cursor is currently over this view (used to show overlay if needed).
    private var isDragTargeted: Bool = false

    // MARK: - Init

    init(service: SFTPBrowserService) {
        self.service = service
        super.init(frame: .zero)
        // Register for Finder file URL drags (cross-application drops).
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFileURLs(in: sender) else { return [] }
        isDragTargeted = true
        showDropOverlay(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFileURLs(in: sender) else { return [] }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragTargeted = false
        showDropOverlay(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            return false
        }

        let targetPath = service.currentPath
        for url in urls {
            Task { @MainActor in
                try? await service.upload(localURL: url, toRemotePath: targetPath)
            }
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isDragTargeted = false
        showDropOverlay(false)
        // Refresh the listing after upload initiates.
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 300_000_000)
            try? await service.listDirectory(path: service.currentPath)
        }
    }

    // MARK: - Visual feedback

    private func showDropOverlay(_ show: Bool) {
        layer?.backgroundColor = show
            ? NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            : CGColor.clear
        layer?.borderWidth = show ? 2 : 0
        layer?.borderColor = show ? NSColor.controlAccentColor.cgColor : nil
        layer?.cornerRadius = 4
    }

    // MARK: - Helpers

    private func hasFileURLs(in sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                                                options: [.urlReadingFileURLsOnly: true])
    }
}
