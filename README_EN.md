# yapyap

[中文](README.md)

Lightweight macOS menu bar voice input tool. Hold `fn` to speak, transcribed text is inserted at the cursor in real time.

Native Swift, with **cloud + local speech recognition** and **AI post-processing** (online APIs or local LLM) — one app covers the entire path from "hold and talk" to "polished, corrected text".

## Features

### 🎙️ Speech Recognition — Cloud + Local

**Online** — [Doubao Seed ASR](https://www.volcengine.com/docs/6561/163043), high accuracy on mixed Chinese/English, low latency.

**Local** — Fully offline, nothing leaves your machine, powered by [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx):

| Model | Size | Languages |
|-------|------|-----------|
| SenseVoice Small | ~155 MB | zh / en / ja / ko / yue |
| Whisper Small | ~610 MB | 99 languages |
| Whisper Medium | ~1.8 GB | 99 languages, higher accuracy |

Download, switch, and delete models directly from the Settings panel.

<img src="images/settings_asr.png" width="420" alt="Speech Model settings" />

### ✨ AI Post-Processing — Cloud + Local

Raw ASR output often has typos, inconsistent punctuation, and misrecognized proper nouns. yapyap ships with a built-in post-processor: after transcription, the text is routed through an LLM for correction before it lands at your cursor.

**Online mode** — Any OpenAI-compatible provider, one tap to switch:

- OpenAI
- DeepSeek
- SiliconFlow
- Groq
- Moonshot
- Custom base URL (any OpenAI-compatible endpoint)

**Local mode** — Bundled support for Qwen3 4B Instruct (~2.1 GB), one-click download, runs fully offline.

**Customizable system prompt** — Stick with the recommended default, or swap in your own instructions.

**Glossary terms** — Add proper nouns you use often (e.g. "Claude Code", "yapyap") and AI post-processing will guarantee they're spelled correctly, fixing recognition mistakes like "cloud code → Claude Code".

<img src="images/settings_ai.png" width="420" alt="AI Post-Processing settings" />

### 📝 Formatting — Dial in the Details

Optional punctuation and Chinese/English spacing rules so the output fits your writing context (code / prose / chat).

**Punctuation**

| Mode | Example |
|------|---------|
| Keep original | Output raw ASR result as-is |
| Replace with spaces | `你好,世界。` → `你好 世界` |
| Remove trailing | `你好,世界。` → `你好,世界` |
| Keep all | `你好,世界。` → `你好,世界。` |

**Number / English spacing**

| Mode | Example |
|------|---------|
| Keep original | Output raw ASR result as-is |
| No spaces | `测试test数据` → `测试test数据` |
| Add spaces | `测试test数据` → `测试 test 数据` |

<img src="images/settings_formatting.png" width="420" alt="Formatting settings" />

### 🎛️ Two Ways to Record

- **Hold mode** — Press and hold `fn` to record, release to stop. Best for quick phrases.
- **Tap mode** — Tap `fn` once to start, tap again to stop. Best for longer passages — no fingers held down.

yapyap distinguishes the two automatically (releasing `fn` within 0.3s counts as a tap).

### 🧰 And More

- **Works everywhere** — Any app: browsers, editors, terminals, …
- **Recording overlay** — Capsule-shaped waveform animation at the bottom of the screen
- **Bilingual UI** — English / 中文, switchable in Settings
- **Sound feedback** — Optional start/stop sounds, two themes
- **Hideable menu bar icon** — Keep your menu bar tidy if you'd rather not see the icon

<img src="images/settings_general.png" width="420" alt="General settings" />

## Usage

### Cloud ASR (recommended for quick start)

1. Get your App Key and Access Key from the [Volcengine Console](https://console.volcengine.com/speech/service/10038)
2. Open yapyap → Settings → Speech Model → Online, enter your App Key, Access Key, and select a Resource ID
3. Click "Test Connection" to verify the configuration
4. In System Settings → Keyboard, set "Press 🌐 key to" → "Do Nothing"
5. Hold `fn` in any app to start voice input

### Local ASR (fully offline)

1. Open yapyap → Settings → Speech Model → Local Model
2. Pick a model and download it (start with SenseVoice Small — it's small and fast)
3. Once downloaded, click "Select" to make it active
4. Hold `fn` to transcribe offline

### Enable AI post-processing (optional)

1. Open yapyap → Settings → Post-Processing → Enable AI text correction
2. Pick "Online" and plug in an OpenAI-compatible API, or pick "Local Model" to download Qwen3
3. (Optional) Add frequently-used proper nouns under "Terms"
4. From then on, every transcription passes through the LLM for correction before being inserted at the cursor

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
