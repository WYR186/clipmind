import Foundation

struct DownloadTaskResult: Sendable {
    let outputPath: String
    let outputFileName: String
    let commandResult: CommandExecutionResult
}
