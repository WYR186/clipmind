import Foundation

struct ConsoleLogger: AppLoggerProtocol {
    func debug(_ message: String) {
        print("[DEBUG] \(message)")
    }

    func info(_ message: String) {
        print("[INFO] \(message)")
    }

    func error(_ message: String) {
        print("[ERROR] \(message)")
    }
}
