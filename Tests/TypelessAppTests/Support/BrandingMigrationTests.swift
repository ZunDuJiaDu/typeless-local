import Foundation
import Testing

struct BrandingMigrationTests {
    @Test func infoPlistUsesWuZiBrandingAndKeepsMenuBarBehavior() throws {
        let plist = try loadPlist(at: "Resources/Info.plist")

        #expect(plist["CFBundleExecutable"] as? String == "WuZi")
        #expect(plist["CFBundleIdentifier"] as? String == "com.wuzi.local")
        #expect(plist["CFBundleName"] as? String == "WuZi")
        #expect(plist["LSUIElement"] as? Bool == true)
        #expect((plist["NSMicrophoneUsageDescription"] as? String)?.contains("WuZi") == true)
        #expect((plist["NSSpeechRecognitionUsageDescription"] as? String)?.contains("WuZi") == true)
    }

    @Test func packageManifestBuildScriptsAndDocsUseWuZiNaming() throws {
        let packageManifest = try readFile(at: "Package.swift")
        #expect(packageManifest.contains("name: \"WuZi\""))
        #expect(packageManifest.contains(".library(name: \"WuZiKit\""))
        #expect(packageManifest.contains(".executable(name: \"WuZi\""))

        let makefile = try readFile(at: "Makefile")
        #expect(makefile.contains("APP_NAME := WuZi"))

        let buildScript = try readFile(at: "scripts/build-app.sh")
        #expect(buildScript.contains("APP_NAME=\"WuZi\""))

        let installScript = try readFile(at: "scripts/install-app.sh")
        #expect(installScript.contains("APP_NAME=\"WuZi\""))

        let verifyScript = try readFile(at: "scripts/verify-app.sh")
        #expect(verifyScript.contains("APP_NAME=\"WuZi\""))

        let readme = try readFile(at: "README.md")
        #expect(readme.contains("# WuZi"))
        #expect(readme.contains("~/Applications/WuZi.app"))

        let manualChecklist = try readFile(at: "docs/manual-validation-checklist.md")
        #expect(manualChecklist.contains("# WuZi verification checklist"))
        #expect(manualChecklist.contains("dist/WuZi.app"))
    }

    @Test func installAndRunScriptsDocumentInstalledBundleValidationPath() throws {
        let runScript = try readFile(at: "scripts/run-app.sh")
        #expect(runScript.contains("RUN_FROM_DIST"))
        #expect(runScript.contains("USER_APP=\"${HOME}/Applications/${APP_NAME}.app\""))
        #expect(runScript.contains("SYSTEM_APP=\"/Applications/${APP_NAME}.app\""))
        #expect(runScript.contains("freshly rebuilt dist/${APP_NAME}.app"))

        let installScript = try readFile(at: "scripts/install-app.sh")
        #expect(installScript.contains("manual validation"))
        #expect(installScript.contains("dist/${APP_NAME}.app"))

        let verifyScript = try readFile(at: "scripts/verify-app.sh")
        #expect(verifyScript.contains("installed app bundle"))
        #expect(verifyScript.contains("TCC"))
    }
}

private func loadPlist(at relativePath: String) throws -> [String: Any] {
    let url = repoRoot.appending(path: relativePath)
    guard let plist = NSDictionary(contentsOf: url) as? [String: Any] else {
        throw NSError(domain: "BrandingMigrationTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to load plist at \(relativePath)"
        ])
    }
    return plist
}

private func readFile(at relativePath: String) throws -> String {
    try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
}

private let repoRoot: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
