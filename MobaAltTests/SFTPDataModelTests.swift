import Testing
import Foundation
@testable import MobaAlt

// MARK: - SFTPItem Tests

struct SFTPItemTests {
    @Test func testDirectoryItemHasCorrectFlag() {
        let item = SFTPItem(
            name: "Documents",
            path: "/home/user/Documents",
            size: 0,
            modificationDate: Date(),
            isDirectory: true,
            permissions: "drwxr-xr-x"
        )
        #expect(item.isDirectory == true)
    }

    @Test func testFileItemHasCorrectFlag() {
        let item = SFTPItem(
            name: "readme.txt",
            path: "/home/user/readme.txt",
            size: 1024,
            modificationDate: Date(),
            isDirectory: false,
            permissions: "-rw-r--r--"
        )
        #expect(item.isDirectory == false)
        #expect(item.id == "/home/user/readme.txt")
    }
}

// MARK: - TransferProgress Tests

struct TransferProgressTests {
    @Test func testFractionCompletedCalculation() {
        let progress = TransferProgress(bytesTransferred: 500, totalBytes: 1000)
        #expect(progress.fractionCompleted == 0.5)
    }

    @Test func testFractionCompletedWithZeroTotal() {
        let progress = TransferProgress(bytesTransferred: 0, totalBytes: 0)
        // Should not divide by zero; max(1, totalBytes) guard applies.
        #expect(progress.fractionCompleted == 0.0)
    }
}

// MARK: - SFTPPanelPosition Tests

struct SFTPPanelPositionTests {
    @Test func testRawRepresentableRoundtrip() {
        let rawValue = "left"
        let position = SFTPPanelPosition(rawValue: rawValue)
        #expect(position == .left)
        #expect(position?.rawValue == rawValue)
    }

    @Test func testAllCasesPresent() {
        let cases = SFTPPanelPosition.allCases
        #expect(cases.contains(.left))
        #expect(cases.contains(.right))
        #expect(cases.contains(.bottom))
        #expect(cases.contains(.hidden))
        #expect(cases.count == 4)
    }

    @Test func testDisplayNames() {
        #expect(SFTPPanelPosition.left.displayName == "Left")
        #expect(SFTPPanelPosition.hidden.displayName == "Hidden")
    }
}
