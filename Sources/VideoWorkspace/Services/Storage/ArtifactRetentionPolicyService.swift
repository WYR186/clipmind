import Foundation

// MARK: - Policy model

public struct ArtifactRetentionPolicy: Codable, Hashable, Sendable {
    /// Maximum age of artifact files in days. 0 = disabled.
    public var maxAgeDays: Int
    /// Maximum number of artifact files to keep per directory. 0 = disabled.
    public var maxFileCount: Int
    /// Maximum total size in bytes across the export directory. 0 = disabled.
    public var maxTotalSizeBytes: Int64

    public static let `default` = ArtifactRetentionPolicy(
        maxAgeDays: 30,
        maxFileCount: 2000,
        maxTotalSizeBytes: 10 * 1024 * 1024 * 1024 // 10 GB
    )

    public static let relaxed = ArtifactRetentionPolicy(
        maxAgeDays: 90,
        maxFileCount: 10000,
        maxTotalSizeBytes: 50 * 1024 * 1024 * 1024 // 50 GB
    )

    public static let disabled = ArtifactRetentionPolicy(
        maxAgeDays: 0,
        maxFileCount: 0,
        maxTotalSizeBytes: 0
    )

    public init(maxAgeDays: Int, maxFileCount: Int, maxTotalSizeBytes: Int64) {
        self.maxAgeDays = maxAgeDays
        self.maxFileCount = maxFileCount
        self.maxTotalSizeBytes = maxTotalSizeBytes
    }

    public var isEffectivelyDisabled: Bool {
        maxAgeDays == 0 && maxFileCount == 0 && maxTotalSizeBytes == 0
    }
}

// MARK: - Result summary

public struct RetentionPolicySummary: Sendable {
    public let removedFileCount: Int
    public let removedBytes: Int64
    public let appliedAt: Date

    public var formattedRemovedBytes: String {
        ByteCountFormatter.string(fromByteCount: removedBytes, countStyle: .file)
    }
}

// MARK: - Protocol

public protocol ArtifactRetentionPolicyServiceProtocol: Sendable {
    func applyPolicy(_ policy: ArtifactRetentionPolicy, exportDirectory: String) async -> RetentionPolicySummary
}

// MARK: - Implementation

struct ArtifactRetentionPolicyService: ArtifactRetentionPolicyServiceProtocol {
    let logger: any AppLoggerProtocol

    init(logger: any AppLoggerProtocol) {
        self.logger = logger
    }

    func applyPolicy(_ policy: ArtifactRetentionPolicy, exportDirectory: String) async -> RetentionPolicySummary {
        guard !policy.isEffectivelyDisabled else {
            return RetentionPolicySummary(removedFileCount: 0, removedBytes: 0, appliedAt: Date())
        }

        let expanded = NSString(string: exportDirectory).expandingTildeInPath
        let directoryURL = URL(fileURLWithPath: expanded)
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return RetentionPolicySummary(removedFileCount: 0, removedBytes: 0, appliedAt: Date())
        }

        var candidates = collectFiles(in: directoryURL, fileManager: fileManager)

        // Sort by modification date ascending (oldest first)
        candidates.sort { $0.modifiedAt < $1.modifiedAt }

        var toRemove: Set<String> = []

        // 1. Age-based pruning
        if policy.maxAgeDays > 0 {
            let cutoff = Date().addingTimeInterval(-Double(policy.maxAgeDays) * 86400)
            for entry in candidates where entry.modifiedAt < cutoff {
                toRemove.insert(entry.path)
            }
        }

        // 2. Count-based pruning (after age removal)
        if policy.maxFileCount > 0 {
            let remaining = candidates.filter { !toRemove.contains($0.path) }
            if remaining.count > policy.maxFileCount {
                let excess = remaining.count - policy.maxFileCount
                for entry in remaining.prefix(excess) {
                    toRemove.insert(entry.path)
                }
            }
        }

        // 3. Size-based pruning (after age + count removal)
        if policy.maxTotalSizeBytes > 0 {
            let remaining = candidates.filter { !toRemove.contains($0.path) }
            var totalSize = remaining.reduce(Int64(0)) { $0 + $1.sizeBytes }
            for entry in remaining where totalSize > policy.maxTotalSizeBytes {
                toRemove.insert(entry.path)
                totalSize -= entry.sizeBytes
            }
        }

        // Remove files
        var removedCount = 0
        var removedBytes: Int64 = 0
        for path in toRemove {
            let size = candidates.first(where: { $0.path == path })?.sizeBytes ?? 0
            do {
                try fileManager.removeItem(atPath: path)
                removedCount += 1
                removedBytes += size
            } catch {
                logger.error("RetentionPolicy: failed to remove \(path): \(error.localizedDescription)")
            }
        }

        if removedCount > 0 {
            logger.info("RetentionPolicy: removed \(removedCount) files (\(ByteCountFormatter.string(fromByteCount: removedBytes, countStyle: .file)))")
        }

        return RetentionPolicySummary(
            removedFileCount: removedCount,
            removedBytes: removedBytes,
            appliedAt: Date()
        )
    }

    // MARK: Helpers

    private struct FileEntry {
        let path: String
        let modifiedAt: Date
        let sizeBytes: Int64
    }

    private func collectFiles(in directory: URL, fileManager: FileManager) -> [FileEntry] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var entries: [FileEntry] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            entries.append(FileEntry(
                path: url.path,
                modifiedAt: values.contentModificationDate ?? .distantPast,
                sizeBytes: Int64(values.fileSize ?? 0)
            ))
        }
        return entries
    }
}
