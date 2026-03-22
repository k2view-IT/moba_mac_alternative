import Testing
import Foundation
@testable import MobaAlt

/// Wave 0 Nyquist stubs — verify compilation and establish test anchors.
/// Real implementations land in 03-03 (file transfer plan).
struct SFTPFileTransferTests {

    @Test func testUploadProgressTracking() async throws {
        // TODO: implement in 03-03 when upload is supported
        Issue.record("testUploadProgressTracking: not implemented until 03-03")
    }

    @Test func testDownloadProgressTracking() async throws {
        // TODO: implement in 03-03 when download is supported
        Issue.record("testDownloadProgressTracking: not implemented until 03-03")
    }

    @Test func testMultipleSimultaneousTransfers() async throws {
        // TODO: implement in 03-03 when concurrent transfer queue is implemented
        Issue.record("testMultipleSimultaneousTransfers: not implemented until 03-03")
    }
}
