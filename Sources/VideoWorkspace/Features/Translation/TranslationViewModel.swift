import Foundation
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceLanguage: String = ""
    @Published var targetLanguage: String = "en"
    @Published var selectedProvider: ProviderType = .openAI
    @Published var selectedModelID: String = ""
    @Published var availableModels: [ModelDescriptor] = []
    @Published var mode: TranslationMode = .plain
    @Published var style: TranslationStyle = .faithful
    @Published var bilingualOutputEnabled: Bool = false
    @Published var preserveTimestamps: Bool = true
    @Published var preserveTerminology: Bool = true

    @Published var exportTXT: Bool = true
    @Published var exportSRT: Bool = false
    @Published var exportVTT: Bool = false
    @Published var exportMarkdown: Bool = true
    @Published var outputDirectoryInput: String = ""

    @Published var translationResult: TranslationResult?
    @Published var translatedPreview: String = ""
    @Published var bilingualPreview: String = ""
    @Published var statusMessage: String = ""
    @Published var latestError: UserFacingError?
    @Published var isRunning: Bool = false
    @Published private(set) var isAdvancedMode: Bool = false

    private let environment: AppEnvironment
    private let source: MediaSource
    private let transcript: TranscriptItem
    private var activeTranslationTask: Task<Void, Never>?

    var exportFormatSummary: String {
        var formats: [String] = []
        if exportTXT { formats.append("TXT") }
        if exportSRT { formats.append("SRT") }
        if exportVTT { formats.append("VTT") }
        if exportMarkdown { formats.append("Markdown") }
        return formats.isEmpty ? "No formats selected" : "Will export: \(formats.joined(separator: ", "))"
    }

    init(
        environment: AppEnvironment,
        source: MediaSource,
        transcript: TranscriptItem,
        defaultBilingual: Bool = false
    ) {
        self.environment = environment
        self.source = source
        self.transcript = transcript
        self.sourceLanguage = transcript.detectedLanguage ?? transcript.languageCode
        self.bilingualOutputEnabled = defaultBilingual
        self.mode = defaultBilingual ? .bilingual : Self.defaultMode(for: transcript)

        Task {
            await loadDefaults()
            await loadModels()
            await loadPresentationPreferences()
        }
    }

    func loadModels() async {
        availableModels = (try? await environment.modelDiscoveryService.discoverModels(for: selectedProvider)) ?? []
        if selectedModelID.isEmpty {
            selectedModelID = availableModels.first?.id ?? ""
        }
    }

    func translate() {
        activeTranslationTask?.cancel()
        activeTranslationTask = Task {
            await runTranslation()
        }
    }

    func cancelTranslation() {
        activeTranslationTask?.cancel()
        activeTranslationTask = nil
        isRunning = false
        statusMessage = "Translation cancelled"
    }

    func browseOutputDirectory() {
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Output Directory"
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectoryInput = url.path
        }
        #endif
    }

    func copyTranslatedText() {
        guard let value = translationResult?.translatedText else { return }
        copyToPasteboard(value)
    }

    func copyBilingualText() {
        guard let value = translationResult?.bilingualText else { return }
        copyToPasteboard(value)
    }

    func revealArtifact(path: String) {
        #if canImport(AppKit)
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        #endif
    }

    private func runTranslation() async {
        isRunning = true
        defer { isRunning = false }

        let coordinator = TaskExecutionCoordinator(
            taskRepository: environment.taskRepository,
            historyRepository: environment.historyRepository,
            artifactIndexingService: environment.artifactIndexingService,
            tempFileCleanupService: environment.tempFileCleanupService,
            logger: environment.logger,
            notificationService: environment.notificationService
        )

        var task = TaskItem(source: source, taskType: .translate)
        await coordinator.addTask(task)
        let settings = await environment.settingsRepository.loadSettings()

        let request = TranslationRequest(
            taskID: task.id,
            sourceTranscriptID: transcript.id,
            sourceText: transcript.content,
            sourceSegments: transcript.segments,
            sourceFormat: transcript.format,
            languagePair: TranslationLanguagePair(
                sourceLanguage: normalizedSourceLanguage(),
                targetLanguage: normalizedTargetLanguage()
            ),
            provider: selectedProvider,
            modelID: selectedModelID,
            mode: effectiveMode(),
            style: style,
            bilingualOutputEnabled: bilingualOutputEnabled,
            preserveTimestamps: effectivePreserveTimestamps(),
            preserveTerminology: preserveTerminology,
            outputFormats: selectedOutputFormats(),
            outputDirectory: normalizedOutputDirectory(),
            overwritePolicy: settings.defaults.overwritePolicy,
            debugDiagnosticsEnabled: isAdvancedMode
        )

        do {
            task = await coordinator.updateTask(
                task,
                status: .running,
                progress: TaskProgressFactory.step(0.03, description: "Preparing translation")
            )

            let taskID = task.id
            let result = try await environment.translationService.translate(
                request: request,
                progressHandler: { progress in
                    Task {
                        if let current = await self.environment.taskRepository.task(id: taskID) {
                            _ = await coordinator.updateTask(
                                current,
                                status: .running,
                                progress: progress
                            )
                        }
                    }
                }
            )

            let latestTask = await environment.taskRepository.task(id: taskID) ?? task
            await coordinator.completeTask(
                latestTask,
                transcript: transcript,
                summary: nil,
                translation: result,
                outputPath: result.artifacts.first?.path
            )

            translationResult = result
            translatedPreview = String(result.translatedText.prefix(1200))
            bilingualPreview = String((result.bilingualText ?? "").prefix(1200))
            latestError = nil
            statusMessage = "Translation completed"
        } catch {
            let mapped = ErrorPresentationMapper.map(error, context: "Translation")
            latestError = mapped
            statusMessage = mapped.message
            await coordinator.failTask(
                task,
                error: TaskError(code: mapped.code, message: mapped.message, technicalDetails: mapped.diagnostics)
            )
        }
    }

    private func loadDefaults() async {
        let settings = await environment.settingsRepository.loadSettings()
        targetLanguage = settings.defaults.summaryLanguage
        selectedProvider = settings.defaults.summaryProvider
        selectedModelID = settings.defaults.summaryModelID
        outputDirectoryInput = settings.defaults.exportDirectory
    }

    private func loadPresentationPreferences() async {
        let settings = await environment.settingsRepository.loadSettings()
        isAdvancedMode = !settings.simpleModeEnabled
    }

    private func selectedOutputFormats() -> [TranslationOutputFormat] {
        var formats: [TranslationOutputFormat] = []
        if exportTXT { formats.append(.txt) }
        if exportSRT { formats.append(.srt) }
        if exportVTT { formats.append(.vtt) }
        if exportMarkdown { formats.append(.markdown) }
        if formats.isEmpty {
            formats = [.txt]
        }
        return formats
    }

    private func normalizedSourceLanguage() -> String {
        let trimmed = sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "auto" {
            return transcript.detectedLanguage ?? transcript.languageCode
        }
        return trimmed
    }

    private func normalizedTargetLanguage() -> String {
        let trimmed = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "en" : trimmed
    }

    private func normalizedOutputDirectory() -> String? {
        let trimmed = outputDirectoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func effectiveMode() -> TranslationMode {
        if mode == .subtitlePreserving, transcript.segments.isEmpty {
            return bilingualOutputEnabled ? .bilingual : .plain
        }
        if bilingualOutputEnabled && mode == .plain {
            return .bilingual
        }
        return mode
    }

    private func effectivePreserveTimestamps() -> Bool {
        if effectiveMode() == .subtitlePreserving {
            return true
        }
        return preserveTimestamps
    }

    private static func defaultMode(for transcript: TranscriptItem) -> TranslationMode {
        switch transcript.format {
        case .srt, .vtt:
            return .subtitlePreserving
        case .txt:
            return .plain
        }
    }

    private func copyToPasteboard(_ value: String) {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #endif
    }
}
