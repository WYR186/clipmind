# VideoWorkspace Release Checklist

## Build and Test
- [ ] `swift build` succeeds on release candidate branch.
- [ ] `swift test` passes with no failures.
- [ ] No new compiler warnings in release candidate scope.

## Runtime Readiness
- [ ] Smoke checklist result is acceptable on a clean test machine.
- [ ] `yt-dlp`, `ffmpeg`, and `ffprobe` availability verified.
- [ ] Database path is writable and readable.
- [ ] Keychain availability verified.
- [ ] Logs and export directories are writable.

## Main Flow Validation
- [ ] Online URL inspect flow verified.
- [ ] Online export flow verified.
- [ ] Local file inspect flow verified.
- [ ] Local transcription flow verified.
- [ ] Summarization flow verified with at least one cloud and one local provider.

## Diagnostics and Support
- [ ] Diagnostics bundle export works.
- [ ] Diagnostics bundle contains no secrets.
- [ ] Support summary copy action works.
- [ ] Recent failure summaries are visible for troubleshooting.

## Release Safety
- [ ] Release runtime does not silently fallback to mock adapters.
- [ ] Debug runtime fallback behavior still works for development.
- [ ] Error presentation remains user-friendly in simple mode and detailed in advanced mode.
