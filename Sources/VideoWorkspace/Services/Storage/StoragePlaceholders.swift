import Foundation

enum StoragePlaceholders {
    /// Key used to mark that artifact indexing is active for this session.
    static let artifactIndexingEnabledKey = "artifact_indexing_enabled"
    /// Directory name used for temporary transcription scratch files.
    static let tempTranscriptionSubdirectory = "videoworkspace-transcribe"
    /// Default export subdirectory relative to the user's home directory.
    static let defaultExportSubdirectory = "Downloads/VideoWorkspace"
}
