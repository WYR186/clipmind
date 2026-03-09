import Foundation

enum OutputPathError: Error, Sendable {
    case invalidDirectory(String)
    case cannotCreateDirectory(String)
    case noResolvedPath
}
