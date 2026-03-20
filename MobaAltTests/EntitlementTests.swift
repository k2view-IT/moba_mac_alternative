import Testing
import Foundation

/// Tests that confirm the Hardened Runtime + no-App-Sandbox entitlement configuration
/// allows process spawning and other OS interactions required by the app.
struct EntitlementTests {

    /// Verify that Foundation.Process can spawn a subprocess successfully.
    ///
    /// This test would fail if App Sandbox were enabled without the
    /// com.apple.security.temporary-exception.sbpl entitlement, proving
    /// that our entitlements config (Hardened Runtime, no sandbox) is correct.
    @Test func testProcessSpawn() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/echo")
        process.arguments = ["hello"]

        // Capture output to avoid polluting test console
        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
    }
}
