import Foundation

public enum TaskProgressFactory {
    public static func queued() -> TaskProgress {
        TaskProgress(fractionCompleted: 0, currentStep: "Queued")
    }

    public static func step(_ value: Double, description: String) -> TaskProgress {
        TaskProgress(fractionCompleted: value, currentStep: description)
    }
}
