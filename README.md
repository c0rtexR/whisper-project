# Whisper Dictation

System-wide voice dictation for macOS powered by OpenAI's Whisper with optional LLM-based text correction and style transformation.

## Features

### Core Dictation
- **System-wide hotkey** (default: CapsLock) for voice dictation anywhere
- **Toggle or Hold-to-Record** modes
- **Fast local transcription** using Whisper models (tiny to large-v3)
- **GPU acceleration** via Metal for Apple Silicon Macs
- **Transcription history** (Cmd+Shift+H) with both Whisper and LLM versions

### Writing Styles (NEW!) ✨
Transform your transcriptions with 4 different writing styles:

1. **None (Badge: 1)** - Basic error correction only
2. **Professional (Badge: 2)** - Formal business language
3. **Casual (Badge: 3)** - Conversational and friendly tone
4. **Funny (Badge: 4)** - Humorous, Bender-from-Futurama style

**Features:**
- Menu bar badge shows current style number (1-4)
- Settings UI picker (conditional on LLM enabled)
- **Cmd+Shift+S** hotkey to quickly cycle through styles
- Status menu displays current style name

**Requirements:**
- Works best with **Qwen2.5 7B** model (4.7 GB)
- Requires 8GB+ RAM for optimal performance
- Smaller models (0.5B-3B) may struggle with style consistency

## Installation

### Requirements
- macOS 13.0 or later
- Apple Silicon Mac (M1/M2/M3) or Intel Mac
- ~2GB disk space for Whisper models
- Additional 5-10GB for LLM models (optional)

### Download
1. Download the latest release from [Releases](../../releases)
2. Move `WhisperDictation.app` to `/Applications/`
3. Open the app
4. Grant **Microphone** and **Accessibility** permissions when prompted

### First Launch Setup
1. Download a Whisper model (recommended: `large-v3` for best quality)
2. (Optional) Enable LLM correction and download an LLM model
   - For **Writing Styles**: Download **Qwen2.5 7B** or larger
3. Configure your hotkey (default: CapsLock)
4. Choose recording mode (Toggle or Hold-to-Record)

## Usage

### Basic Dictation
1. Press your hotkey to start recording
2. Speak naturally
3. Press hotkey again to stop (Toggle mode) or release key (Hold mode)
4. Text is automatically typed at cursor position

### Writing Styles
1. **Enable LLM correction** in Settings → General
2. **Download Qwen2.5 7B** in Settings → LLM Models tab
3. **Select a style** in Settings → General → Writing style picker
4. **Quick cycle**: Press **Cmd+Shift+S** to cycle through styles
5. **Visual feedback**: Menu bar badge shows current style number

### Keyboard Shortcuts
- **CapsLock** (default): Start/stop recording
- **Cmd+Shift+H**: Open transcription history
- **Cmd+Shift+S**: Cycle writing styles

## Building from Source

### Prerequisites
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Clone llama.cpp and build
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
mkdir build && cd build
cmake .. -DGGML_METAL=ON
make -j
```

### Build Steps
```bash
# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project WhisperDictation.xcodeproj -scheme WhisperDictation -configuration Release build

# Install
cp -R build/Release/WhisperDictation.app /Applications/
```

## Model Downloads

### Whisper Models
Downloaded automatically through the app UI:
- `tiny` (75 MB) - Fastest, lowest quality
- `base` (142 MB) - Fast, decent quality
- `small` (466 MB) - Good balance
- `medium` (1.5 GB) - Better quality
- `large-v3` (3.1 GB) - Best quality (recommended)

### LLM Models (for Writing Styles)
Downloaded through the app UI:
- `Qwen2.5 0.5B` (350 MB) - Basic corrections only, struggles with styles
- `Qwen2.5 1.5B` (950 MB) - Fast but inconsistent with styles
- `Qwen2.5 3B` (1.9 GB) - Better but still inconsistent
- **`Qwen2.5 7B` (4.7 GB)** - **Recommended for Writing Styles** ⭐
- `Llama 3.2 3B` (1.9 GB) - Alternative, good quality

## Troubleshooting

### Recording doesn't start
- Check **Accessibility** permission in System Settings → Privacy & Security
- Try a different hotkey in Settings → Hotkey tab

### No text appears after recording
- Check **Microphone** permission
- Verify model is downloaded in Settings → Whisper Models

### LLM correction not working
- Ensure LLM model is downloaded
- Check that "Use LLM to correct transcriptions" is enabled
- Wait a few seconds for model to load on first use

### Writing styles produce strange results
- Make sure you're using **Qwen2.5 7B** or larger
- Smaller models may answer questions instead of rephrasing
- Restart the app if LLM server becomes unresponsive

## Technical Details

### Architecture
- **Whisper**: C++ (whisper.cpp) for speech recognition
- **LLM**: llama.cpp server for text correction and style transfer
- **Swift/SwiftUI**: Native macOS UI
- **Metal**: GPU acceleration on Apple Silicon

### Writing Styles Implementation
- **Translation-style prompts**: Frames style changes as "translation" tasks
- **Few-shot learning**: Provides examples to guide the LLM
- **Dynamic token limits**: Scales from 64-512 tokens based on input length
- **Repetition penalty**: Prevents LLM loops (1.1-1.15)
- **Temperature**: 0.1 for corrections, 0.3-0.5 for creative styles

## Credits

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - Whisper model inference
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - LLM inference
- [OpenAI Whisper](https://github.com/openai/whisper) - Original Whisper model
- [Qwen Team](https://github.com/QwenLM/Qwen) - Qwen language models

## License

MIT License - see LICENSE file for details
