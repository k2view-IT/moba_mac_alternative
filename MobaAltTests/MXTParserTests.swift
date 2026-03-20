import Testing
import Foundation
@testable import MobaAlt

/// Tests for MobaXterm .mxtsessions file parsing.
struct MXTParserTests {

    // Helper: load sample.mxtsessions from test bundle
    private func loadSampleData() throws -> Data {
        // Use Bundle.allBundles to search all loaded bundles for the resource
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "sample", withExtension: "mxtsessions") {
                return try Data(contentsOf: url)
            }
        }
        // Fallback: try to find by bundle path pattern for Xcode test bundles
        let derivedDataPattern = Bundle.main.bundlePath
        let testBundlePaths = Bundle.allBundles.compactMap { $0.resourcePath }
        for path in testBundlePaths {
            let filePath = path + "/sample.mxtsessions"
            if FileManager.default.fileExists(atPath: filePath) {
                return try Data(contentsOf: URL(fileURLWithPath: filePath))
            }
        }
        throw NSError(domain: "MXTParserTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "sample.mxtsessions not found in test bundle"])
    }

    @Test func testParseSSHSession() throws {
        let data = try loadSampleData()
        let parser = MXTSessionsParser()
        let result = try parser.parse(data: data)

        let webServer = result.sessions.first { $0.session.name == "Web Server" }
        #expect(webServer != nil, "Expected 'Web Server' session")
        guard let ws = webServer else { return }
        #expect(ws.session.name == "Web Server")
        #expect(ws.session.protocolConfig.hostname == "192.168.1.100")
        #expect(ws.session.protocolConfig.port == 22)
        if case .ssh(let cfg) = ws.session.protocolConfig {
            #expect(cfg.username == "admin")
        } else {
            Issue.record("Expected SSH config for 'Web Server'")
        }
        // Root session — no folder
        #expect(ws.folderId == nil, "Web Server should be at root")
    }

    @Test func testParseFolderStructure() throws {
        let data = try loadSampleData()
        let parser = MXTSessionsParser()
        let result = try parser.parse(data: data)

        // "Production" folder should exist at root
        let productionFolder = result.folders.first { $0.name == "Production" }
        #expect(productionFolder != nil, "Expected 'Production' folder")
        guard let prod = productionFolder else { return }
        #expect(prod.parentId == nil, "Production folder should be at root level")

        // "DB" subfolder should exist under "Production"
        let dbFolder = result.folders.first { $0.name == "DB" }
        #expect(dbFolder != nil, "Expected 'DB' folder")
        guard let db = dbFolder else { return }
        #expect(db.parentId == prod.id, "DB folder should be a child of Production")

        // "Win Server" should be in the Production folder
        let winServer = result.sessions.first { $0.session.name == "Win Server" }
        #expect(winServer != nil, "Expected 'Win Server' session")
        #expect(winServer?.folderId == prod.id, "Win Server should be in Production folder")

        // "DB Monitor" should be in the DB subfolder
        let dbMonitor = result.sessions.first { $0.session.name == "DB Monitor" }
        #expect(dbMonitor != nil, "Expected 'DB Monitor' session")
        #expect(dbMonitor?.folderId == db.id, "DB Monitor should be in DB folder")
    }

    @Test func testParseRDPAndVNC() throws {
        let data = try loadSampleData()
        let parser = MXTSessionsParser()
        let result = try parser.parse(data: data)

        let winServer = result.sessions.first { $0.session.name == "Win Server" }
        #expect(winServer != nil, "Expected RDP 'Win Server'")
        if case .rdp(let cfg) = winServer?.session.protocolConfig {
            #expect(cfg.port == 3389)
            #expect(cfg.hostname == "10.0.0.5")
        } else {
            Issue.record("Expected RDP config for 'Win Server'")
        }

        let dbMonitor = result.sessions.first { $0.session.name == "DB Monitor" }
        #expect(dbMonitor != nil, "Expected VNC 'DB Monitor'")
        if case .vnc(let cfg) = dbMonitor?.session.protocolConfig {
            #expect(cfg.port == 5900)
            #expect(cfg.hostname == "10.0.0.10")
        } else {
            Issue.record("Expected VNC config for 'DB Monitor'")
        }
    }

    @Test func testSpecialEncodings() throws {
        // Create test data with __PTVIRG__ in session name and host
        let iniContent = """
        [Bookmarks]
        SubRep=
        ImgNum=42
        Semi__PTVIRG__colon=#109#0%192.168.1.1%22%user%-1%-1%%%%%0%0%0%%%-1%0%0%0%%1080%%0%0%1##0#0#0#0#

        """
        let data = iniContent.data(using: .utf8)!
        let parser = MXTSessionsParser()
        let result = try parser.parse(data: data)
        #expect(result.sessions.count == 1, "Expected 1 session with special encoding")
        let session = result.sessions[0].session
        #expect(session.name == "Semi;colon", "Expected __PTVIRG__ decoded to semicolon, got: \(session.name)")
    }
}
