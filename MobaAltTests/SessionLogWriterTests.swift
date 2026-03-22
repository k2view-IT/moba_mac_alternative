import Testing
import Foundation
@testable import MobaAlt

struct SessionLogWriterTests {
    @Test func testWritesBytesToFile() async throws {
        // Create a temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let logURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).log")

        // Create an empty file so FileHandle can open it
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let writer = try SessionLogWriter(logFileURL: logURL)

        // "Hello" in ASCII bytes
        let bytes: ArraySlice<UInt8> = [72, 101, 108, 108, 111]
        await writer.write(bytes)
        await writer.close()

        // Verify file contents
        let writtenData = try Data(contentsOf: logURL)
        #expect(writtenData == Data([72, 101, 108, 108, 111]))

        // Cleanup
        try? FileManager.default.removeItem(at: logURL)
    }
}
