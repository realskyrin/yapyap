# yapyap

[中文](README.md)

Lightweight macOS menu bar voice input tool (~700KB). Hold `fn` to speak, transcribed text is inserted at the cursor in real time.

A native Swift [Doubao Seed ASR](https://www.volcengine.com/docs/6561/163043) client with zero third-party dependencies.

## Features

- **Hold to record** — Hold fn to start recording, release to stop, text is inserted at cursor in real time
- **Works everywhere** — Use in any app, including browsers, editors, terminals, etc.
- **Real-time recognition** — Powered by Doubao Seed ASR, supports mixed Chinese-English recognition with 99% accuracy
- **Recording indicator** — Capsule-shaped waveform animation overlay at the bottom of the screen while recording

## Text Processing

yapyap provides flexible post-processing options to tailor recognition results to your use case:

### Punctuation

| Mode | Example |
|------|---------|
| Keep original | Output raw ASR result as-is |
| Replace with spaces | `你好，世界。` → `你好 世界` |
| Remove trailing | `你好，世界。` → `你好，世界` |
| Keep all | `你好，世界。` → `你好，世界。` |

### Number / English Spacing

| Mode | Example |
|------|---------|
| Keep original | Output raw ASR result as-is |
| No spaces | `测试test数据` → `测试test数据` |
| Add spaces | `测试test数据` → `测试 test 数据` |

<img src="images/settings.png" width="420" alt="yapyap Settings" />

## Usage

1. Get your App Key and Access Key from the [Volcengine Console](https://console.volcengine.com/speech/service/10038)
2. Open yapyap Settings, enter your App Key, Access Key, and select a Resource ID
3. Click "Test Connection" to verify the configuration
4. In System Settings → Keyboard, set "Press 🌐 key to" → "Do Nothing"
5. Hold `fn` in any app to start voice input

> Microphone and Accessibility permissions are required on first use.

## Requirements

- macOS 14.0+
- Apple Silicon

## Build

```bash
# Generate Xcode project
xcodegen

# Open and build with Xcode
open yapyap.xcodeproj
```
