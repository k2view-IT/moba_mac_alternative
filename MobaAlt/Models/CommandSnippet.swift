import Foundation

struct CommandSnippet: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var body: String

    init(id: UUID = UUID(), name: String, body: String) {
        self.id = id
        self.name = name
        self.body = body
    }
}
