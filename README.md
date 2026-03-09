# VideoWorkspace (Phase 1 Skeleton)

Local-first macOS SwiftUI skeleton for a video-to-text workspace.

## What is included

- SwiftUI app shell with sidebar navigation
- Feature views: Dashboard, Online Video, Local Files, Tasks, History, Settings, Onboarding
- Protocol-first core abstractions for media, transcription, summarization, providers, persistence, logging, notifications
- Core domain models and enums
- In-memory repositories and mock services for end-to-end demo flow
- Shared AppEnvironment-based dependency injection
- Task progress simulation and history persistence in mock repositories

## Run

```bash
swift build
swift run VideoWorkspace
```

## Test

```bash
swift test
```

## Notes

- This phase intentionally avoids real integrations.
- TODO markers are included for SQLite migrations, Keychain implementation, and ffmpeg/yt-dlp adapters.
