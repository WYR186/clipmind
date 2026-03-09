import Foundation

struct PreparedDownloadOutput: Sendable {
    let directoryURL: URL
    let baseFileName: String
    let outputTemplatePath: String
}

struct DownloadOutputResolver {
    private let filenameStrategy: DownloadFilenameStrategy

    init(filenameStrategy: DownloadFilenameStrategy = DownloadFilenameStrategy()) {
        self.filenameStrategy = filenameStrategy
    }

    func prepareOutput(request: MediaDownloadRequest, metadata: MediaMetadata?) throws -> PreparedDownloadOutput {
        let directory = try resolveDirectory(path: request.outputDirectory)
        var baseName = filenameStrategy.makeBaseFileName(request: request, metadata: metadata)

        if request.overwritePolicy == .renameIfNeeded {
            baseName = uniqueBaseNameIfNeeded(baseName, directoryURL: directory)
        }

        let outputTemplatePath = directory.appendingPathComponent("\(baseName).%(ext)s").path
        return PreparedDownloadOutput(directoryURL: directory, baseFileName: baseName, outputTemplatePath: outputTemplatePath)
    }

    func resolveFinalOutputPath(prepared: PreparedDownloadOutput, preferredPath: String?) -> String? {
        if let preferredPath, FileManager.default.fileExists(atPath: preferredPath) {
            return preferredPath
        }

        let directoryPath = prepared.directoryURL.path
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directoryPath) else {
            return nil
        }

        let candidates = entries
            .filter { $0.hasPrefix(prepared.baseFileName) }
            .map { prepared.directoryURL.appendingPathComponent($0) }

        guard !candidates.isEmpty else {
            return nil
        }

        let sorted = candidates.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate > rightDate
        }
        return sorted.first?.path
    }

    private func resolveDirectory(path: String?) throws -> URL {
        let raw = (path?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? path!
            : "~/Downloads/VideoWorkspace"
        let expanded = NSString(string: raw).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw OutputPathError.invalidDirectory(url.path)
            }
            return url
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            throw OutputPathError.cannotCreateDirectory(url.path)
        }
    }

    private func uniqueBaseNameIfNeeded(_ base: String, directoryURL: URL) -> String {
        let directoryPath = directoryURL.path
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directoryPath) else {
            return base
        }

        if !entries.contains(where: { $0.hasPrefix(base) }) {
            return base
        }

        var counter = 2
        while entries.contains(where: { $0.hasPrefix("\(base)-\(counter)") }) {
            counter += 1
        }
        return "\(base)-\(counter)"
    }
}
