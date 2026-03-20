# VideoWorkspace QA Smoke Matrix

| Area | Check | Expected |
| --- | --- | --- |
| Readiness | Run smoke checklist | Status is "All Green" or "Acceptable" |
| Tools | yt-dlp/ffmpeg/ffprobe | Marked as pass in checklist |
| Storage | Export directory writable | Export check passes |
| Storage | Logs directory writable | Logs check passes |
| Persistence | Database healthy | Database check passes |
| Security | Keychain available | Keychain check passes |
| Notifications | Permission state | Displays authorized / optional guidance |
| Providers | Provider configured summary | Configured/unconfigured shown, no key leakage |
| Cache | Provider cache readable | Cache check pass/warning with clear message |
| Cleanup | Last cleanup status | Present or warning with guidance |
| Online Flow | URL inspect -> export | Task completes and artifacts visible |
| Local Flow | File inspect -> transcribe | Transcript artifacts generated |
| Summary Flow | Transcribe -> summarize | Summary result and provider metadata visible |
| Error UX | Missing tool / invalid URL / auth error | User-facing recovery guidance shown |
| Support | Copy support summary | Summary copied without secrets |
| Diagnostics | Export diagnostics bundle | Bundle generated, sanitized, and readable |
