# Whisper Dictation

System-wide voice dictation for macOS. Press a hotkey, speak, text appears at your cursor. Powered by OpenAI Whisper running locally via whisper.cpp.

**[Download Latest Release](https://github.com/c0rtexR/whisper-project/releases)** · [Developer Guide](docs/dev.md)

## Features

- Global hotkey (default CapsLock), toggle or hold-to-record
- Fast paste mode: uses clipboard instead of keystroke simulation
- 99 languages + auto-detect
- Optional LLM text correction via local llama.cpp server
- 5 writing styles: None, Professional, Casual, Funny, Custom
- Audio level indicator while recording
- Live transcription preview while recording (experimental)
- Transcription history (Cmd+Shift+H)
- Auto-updates with background downloads
- Metal GPU acceleration on Apple Silicon

## Requirements

- macOS 13.0+
- Apple Silicon or Intel Mac
- ~2 GB disk for Whisper model, +5 GB if using LLM correction

## Install

1. Download `WhisperDictation-v0.3.0.zip` from [Releases](../../releases)
2. Unzip, move `WhisperDictation.app` to Applications
3. Right-click the app, select "Open" on first launch (required to bypass Gatekeeper since the app is self-signed)
4. Grant permissions when prompted:
   - **Microphone**: needed to record audio
   - **Accessibility**: needed to type text into other apps
5. Download a Whisper model in the setup screen (recommended: large-v3)

## Usage

| Shortcut | Action |
|---|---|
| CapsLock | Start/stop recording |
| Cmd+Shift+S | Cycle writing style |
| Cmd+Shift+H | Transcription history |

Right-click the menu bar icon for settings and style selection.

### LLM Correction & Writing Styles

1. Enable "Use LLM to correct transcriptions" in Settings > General
2. Download an LLM model in Settings > LLM Models (Qwen2.5 7B recommended for styles)
3. Pick a style from the dropdown, or select Custom and write your own prompt using `{text}` as placeholder

The LLM server starts automatically when enabled.

## Models

**Whisper** (speech-to-text), downloaded in-app:

| Model | Size | Quality |
|---|---|---|
| tiny | 75 MB | Low |
| base | 142 MB | Fair |
| small | 466 MB | Good |
| medium | 1.5 GB | Better |
| large-v3 | 3.1 GB | Best |

**LLM** (text correction + styles), optional:

| Model | Size | Notes |
|---|---|---|
| Qwen2.5 0.5B | 350 MB | Basic correction only |
| Qwen2.5 7B | 4.7 GB | Recommended for writing styles |

## Build from Source

```bash
xcodebuild -project WhisperDictation.xcodeproj -scheme WhisperDictation -configuration Release
```

Requires whisper.cpp static libraries in `whisper.cpp/lib/`. See [Developer Guide](docs/dev.md).

## Privacy

All speech processing runs on your Mac. Network is only used for model downloads and update checks against the GitHub releases API.

## Credits

[whisper.cpp](https://github.com/ggerganov/whisper.cpp) · [llama.cpp](https://github.com/ggerganov/llama.cpp) · [OpenAI Whisper](https://github.com/openai/whisper) · [Qwen](https://github.com/QwenLM/Qwen)

## License

All Rights Reserved. See [LICENSE](LICENSE).
