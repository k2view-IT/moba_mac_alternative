import Testing
import Foundation
@testable import MobaAlt

struct SessionLibraryTests {

    // MARK: - Tests

    @Test func testSearch() {
        let library = SessionLibrary()

        let alpha = SessionDefinition(
            name: "Alpha Dev",
            protocolConfig: .ssh(SSHConfig(hostname: "10.0.0.1")),
            sortOrder: 0
        )
        let beta = SessionDefinition(
            name: "Beta Prod",
            protocolConfig: .ssh(SSHConfig(hostname: "10.0.0.2")),
            sortOrder: 1
        )
        let gamma = SessionDefinition(
            name: "Gamma Test",
            protocolConfig: .ssh(SSHConfig(hostname: "192.168.1.50")),
            sortOrder: 2
        )

        library.addSession(alpha)
        library.addSession(beta)
        library.addSession(gamma)

        // Case-insensitive name match
        let betaResults = library.search(query: "beta")
        #expect(betaResults.count == 1)
        #expect(betaResults.first?.name == "Beta Prod")

        // Hostname substring match
        let hostnameResults = library.search(query: "168")
        #expect(hostnameResults.count == 1)
        #expect(hostnameResults.first?.name == "Gamma Test")

        // Empty query returns all sessions
        let allResults = library.search(query: "")
        #expect(allResults.count == 3)
    }
}
