import Foundation

final class FileBackedLogger: @unchecked Sendable, AppLoggerProtocol {
    private let queue = DispatchQueue(label: "VideoWorkspace.FileBackedLogger")
    private let formatter: ISO8601DateFormatter
    private let fileURLValue: URL
    private var recentBuffer: [String] = []
    private let maxBufferSize: Int

    init(
        logDirectory: URL,
        fileName: String = "video-workspace.log",
        maxBufferSize: Int = 500
    ) {
        self.formatter = ISO8601DateFormatter()
        self.fileURLValue = logDirectory.appendingPathComponent(fileName)
        self.maxBufferSize = maxBufferSize

        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURLValue.path) {
            FileManager.default.createFile(atPath: fileURLValue.path, contents: nil)
        }
    }

    func debug(_ message: String) {
        append(level: "DEBUG", message: message)
    }

    func info(_ message: String) {
        append(level: "INFO", message: message)
    }

    func error(_ message: String) {
        append(level: "ERROR", message: message)
    }

    func logFileURL() -> URL? {
        fileURLValue
    }

    func recentEntries(limit: Int) -> [String] {
        queue.sync {
            Array(recentBuffer.suffix(max(0, limit)))
        }
    }

    private func append(level: String, message: String) {
        let line = "[\(level)] \(formatter.string(from: Date())) \(message)"
        print(line)

        queue.async { [fileURLValue, maxBufferSize] in
            self.recentBuffer.append(line)
            if self.recentBuffer.count > maxBufferSize {
                self.recentBuffer.removeFirst(self.recentBuffer.count - maxBufferSize)
            }

            guard let data = (line + "\n").data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURLValue) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }
}
