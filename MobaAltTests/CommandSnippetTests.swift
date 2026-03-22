import Testing
import Foundation
@testable import MobaAlt

struct CommandSnippetTests {
    @Test func testCommandSnippetIsCodable() async throws {
        let id = UUID()
        let snippet = CommandSnippet(id: id, name: "List files", body: "ls -la")

        let data = try JSONEncoder().encode(snippet)
        let decoded = try JSONDecoder().decode(CommandSnippet.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.name == "List files")
        #expect(decoded.body == "ls -la")
    }
}
