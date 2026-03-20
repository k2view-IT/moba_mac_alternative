import SwiftUI
import UniformTypeIdentifiers

/// Drop delegate that handles dragging a session onto a folder to re-parent it.
struct FolderDropDelegate: DropDelegate {
    let targetFolderId: UUID?
    let library: SessionLibrary

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText])
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.plainText])
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let string = object as? String,
                  let sessionId = UUID(uuidString: string) else { return }
            DispatchQueue.main.async {
                guard var session = library.sessions.first(where: { $0.id == sessionId }) else { return }
                session.folderId = targetFolderId
                library.updateSession(session)
            }
        }
        return true
    }
}
