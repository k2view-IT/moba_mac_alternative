// KeychainManagerTests.swift
//
// NOTE: These tests write real Keychain items and require a signing identity.
// They will NOT run on CI without a code-signing identity configured.
// They pass in a locally-signed development build (Debug scheme, Mac Catalyst
// or macOS destination with a valid Development certificate).
//
// Each test uses a unique UUID as the session ID to avoid cross-test pollution.
// The service identifier used is "com.mobaalt.MobaAlt.tests" to isolate from
// production keychain items.

import Testing
import Foundation
@testable import MobaAlt

struct KeychainManagerTests {

    // MARK: - Tests

    @Test func testSaveAndRetrievePassword() async throws {
        let manager = KeychainManager(service: "com.mobaalt.MobaAlt.tests")
        let sessionId = UUID()
        try await manager.savePassword("hunter2", for: sessionId)
        let retrieved = try await manager.getPassword(for: sessionId)
        #expect(retrieved == "hunter2")
        // Cleanup
        try await manager.deletePassword(for: sessionId)
    }

    @Test func testOverwritePassword() async throws {
        let manager = KeychainManager(service: "com.mobaalt.MobaAlt.tests")
        let sessionId = UUID()
        try await manager.savePassword("old_password", for: sessionId)
        try await manager.savePassword("new_password", for: sessionId)
        let retrieved = try await manager.getPassword(for: sessionId)
        #expect(retrieved == "new_password")
        // Cleanup
        try await manager.deletePassword(for: sessionId)
    }

    @Test func testDeletePassword() async throws {
        let manager = KeychainManager(service: "com.mobaalt.MobaAlt.tests")
        let sessionId = UUID()
        try await manager.savePassword("to_delete", for: sessionId)
        try await manager.deletePassword(for: sessionId)
        let retrieved = try await manager.getPassword(for: sessionId)
        #expect(retrieved == nil)
    }

    @Test func testDeleteNonExistentIsIdempotent() async throws {
        let manager = KeychainManager(service: "com.mobaalt.MobaAlt.tests")
        let sessionId = UUID()
        // Should not throw even though this UUID was never saved
        try await manager.deletePassword(for: sessionId)
    }

    @Test func testGetNonExistentReturnsNil() async throws {
        let manager = KeychainManager(service: "com.mobaalt.MobaAlt.tests")
        let sessionId = UUID()
        let result = try await manager.getPassword(for: sessionId)
        #expect(result == nil)
    }
}
