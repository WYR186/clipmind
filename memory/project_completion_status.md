---
name: video_box completion status
description: What has been implemented in the video_box project and what remains
type: project
---

All 10 previously-unfinished items have been implemented (as of 2026-03-20). Build passes with zero errors.

**Why:** User requested complete high-quality implementation of all unfinished work.
**How to apply:** When discussing next steps, refer to this as the baseline completion state.

## Completed items

### High priority
1. **FFmpeg 真实集成** - `FFmpegCommandBuilder.swift` expanded with: audio extraction (MP3/M4A/AAC/WAV/FLAC/Opus), video conversion (MP4/MKV/MOV/WebM), trim/clip, thumbnail extraction, subtitle burn-in. `FFmpegMediaConversionService` now dispatches to appropriate builder method based on `ConversionRequest.operation`. `ConversionQuality` and `ConversionRequest.ConversionOperation` are public enums in `MediaPipelineModels.swift`.

2. **批量任务暂停/恢复** - `BatchJobStatus` has new `.paused` case. `BatchExecutionServiceProtocol` has `pause()` and `resume()` methods. `BatchExecutionCoordinator` implements soft pause (finishes current chunk, marks batch `.paused`, returns from run loop; `resume()` calls `start()` again). `BatchJobsViewModel` exposes `pauseSelectedBatch()` / `resumeSelectedBatch()`. `BatchJobDetailView` shows Pause/Resume buttons.

3. **存储清理策略** - New `ArtifactRetentionPolicyService.swift` with `ArtifactRetentionPolicy` model (maxAgeDays, maxFileCount, maxTotalSizeBytes). File-system level cleanup of export directory. `AppSettings` includes `retentionPolicy: ArtifactRetentionPolicy`. `AppEnvironment` exposes `retentionPolicyService`. `SettingsViewModel.applyRetentionPolicy()` applies it on demand.

### Medium priority
4. **Settings 页面** - Full redesign: General, Appearance, Providers (simple/advanced variants), Defaults, Advanced, Storage/Cache, Retention Policy, Diagnostics, About, Support, Actions sections.

5. **翻译 UI 细节** - Cancel button, output directory browser (NSOpenPanel), export format summary label, better language pair layout with hints.

6. **播放列表选择 UI** - Duration filter (min/max seconds), sort options (default/title/duration), "Select filtered" button, total duration display, improved stats header.

7. **MacTextInputView** - Added `MacSecureInputField` (for API keys), `onSubmit` callback on `MacTextInputField`, `characterLimit` parameter, `LimitedTextInputField` convenience view with counter.

### Low priority
8. **翻译提示词** - `SubtitleTranslationMapper.prompt` rebuilt with structured multi-line instructions, per-style guidance (faithful/natural/concise), subtitle timing constraints, terminology preservation, segment context.

9. **AppTheme 设计系统** - Expanded with: `Spacing` (xs/sm/md/lg/xl/xxl), `Radius` (sm/md/lg/pill), `Icon` sizes, `Animation` presets, `Typography` scale, `Colors` semantic colors, `Shadow` styles. Added `cardStyle()` and `appShadow()` View extensions.

10. **StoragePlaceholders** - Replaced TODO with meaningful constants (`artifactIndexingEnabledKey`, `tempTranscriptionSubdirectory`, `defaultExportSubdirectory`).
