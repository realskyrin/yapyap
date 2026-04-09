# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-04-09

### Changed
- Prefer Xcode 16.3+ in release CI for mlx-swift-lm and add AGENTS.md

## [1.0.1] - 2026-04-09

### Added
- Post-processing pill with quick-switch popover
- Voice model pill with quick-switch popover
- Settings status bar with version label
- StatusPill and QuickSwitchRow primitives
- L10n strings for settings status bar
- Redesigned post-processing UI
- Local AI model UI with download progress in AI tab
- Route AI post-processing to local or online engine
- LocalLLMEngine for local AI text correction via MLX
- LLMModelManager for local AI model download and lifecycle
- `useLocalAI` setting and L10n strings
- `mlx-swift-lm` SPM dependency for local AI
- Model management UI with download progress and mode switching
- Route audio to online or local ASR engine based on mode setting
- LocalASREngine with sherpa-onnx pseudo-streaming transcription
- ModelManager with model catalog, download, and extraction
- ASR mode settings and L10n strings for local model support
- `sherpa-onnx` framework integration for offline ASR
- Sound feedback with theme selection and toggle in settings
- Cancel/confirm action buttons in click-mode overlay
- ESC to cancel recording, dynamic-width text bubble

### Fixed
- Bypass HuggingFace Hub when loading an already-downloaded LLM
- Local LLM bugs surfaced during post-processing UI redesign
- Settings window height for status bar
- Poll disk size for smooth download progress
- Use correct Qwen3 4B Instruct MLX model ID
- Restore build after clean and surface previously swallowed build errors
- Code review issues for local AI
- Last character clipped in overlay bubble
- Last character missing in overlay text preview
- Use int8 SenseVoice model URL and correct archive sizes
- Code review issues — thread safety, URLSession leak, state machine
- Terms tooltip with spoken-to-corrected examples for clarity

### Changed
- Move status bar online hint into `L10n` enum
- Update README

### Documentation
- Clarify build script usage for multi-agent workflows
- Add settings status bar implementation plan and design spec
- Add local AI post-processing implementation plan and design spec
- Add offline model transcription implementation plan and design spec

### Maintenance
- Untrack `.claude` and `.codex` (gitignored)
- Untrack `docs/` (already in gitignore)
- Remove commit-and-push script in favor of `/push` skill

## [0.1.0] - 2026-04-03

- Initial release
