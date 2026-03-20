import Foundation

/// A folder that can contain sessions and other folders, forming a hierarchy.
struct SessionFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var parentId: UUID?          // nil = root-level folder
    var sortOrder: Int
    var isExpanded: Bool = true  // persisted UI state

    init(
        id: UUID = UUID(),
        name: String,
        parentId: UUID? = nil,
        sortOrder: Int = 0,
        isExpanded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.sortOrder = sortOrder
        self.isExpanded = isExpanded
    }
}
