# Developer Documentation

This guide covers building from source, code signing, and contributing to Whisper Dictation.

## Table of Contents
- [Development Setup](#development-setup)
- [Building from Source](#building-from-source)
- [Code Signing](#code-signing)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [Testing](#testing)
- [Release Process](#release-process)

---

## Development Setup

### Prerequisites

**Required:**
- macOS 13.0 or later
- Xcode 14.0+ with Command Line Tools
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation

**Install XcodeGen:**
```bash
brew install xcodegen
```

### Clone and Setup

```bash
# Clone repository
git clone https://github.com/c0rtexR/whisper-project.git
cd whisper-project

# Build whisper.cpp library
cd whisper.cpp
./build_framework.sh
cd ..

# Build llama.cpp server (optional, for LLM features)
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
mkdir build && cd build
cmake .. -DGGML_METAL=ON
make -j
cd ../..

# Generate Xcode project
xcodegen generate

# Open project
open WhisperDictation.xcodeproj
```

### First Build

1. Select the **WhisperDictation** scheme
2. Choose your Mac as the build destination
3. Press **Cmd+B** to build
4. Press **Cmd+R** to run

---

## Building from Source

### Debug Build (Development)

```bash
xcodebuild -project WhisperDictation.xcodeproj \
  -scheme WhisperDictation \
  -configuration Debug \
  build
```

Output: `build/Debug/WhisperDictation.app`

### Release Build (Distribution)

```bash
xcodebuild -project WhisperDictation.xcodeproj \
  -scheme WhisperDictation \
  -configuration Release \
  clean build
```

Output: `build/Release/WhisperDictation.app`

### Install Locally

```bash
# Copy to Applications
cp -R build/Release/WhisperDictation.app /Applications/

# Open
open /Applications/WhisperDictation.app
```

---

## Code Signing

### Current Setup (Self-Signed)

The project uses a **self-signed development certificate** for local development. This is automatically created by Xcode.

#### How It Works

1. **Project Configuration** (`project.yml`):
   ```yaml
   targets:
     WhisperDictation:
       settings:
         CODE_SIGN_IDENTITY: "WhisperDictation-Dev"
         CODE_SIGN_STYLE: Manual
   ```

2. **Certificate Creation** (Automatic):
   - Xcode creates a self-signed certificate on first build
   - Certificate name: `WhisperDictation-Dev`
   - Valid for local development only
   - No Apple Developer account required

3. **Entitlements** (`WhisperDictation.entitlements`):
   ```xml
   <key>com.apple.security.device.microphone</key>
   <true/>
   <key>com.apple.security.automation.apple-events</key>
   <true/>
   ```

#### Verify Signing

```bash
# Check current signing
codesign -dvv /Applications/WhisperDictation.app

# Verify signature
codesign --verify --verbose /Applications/WhisperDictation.app
```

#### For Contributors

**You don't need to do anything!** Xcode will automatically:
1. Create a development certificate if needed
2. Sign the app with your local certificate
3. Allow you to run the app on your Mac

**Important:** Don't commit certificate changes. The `.gitignore` excludes:
- `*.xcuserdata/` - User-specific Xcode settings
- `*.xcodeproj/xcuserdata/` - Signing configurations

### Apple Developer ID (Optional)

For official releases with Apple notarization, see [`SIGNING_WITH_APPLE_ID.md`](../SIGNING_WITH_APPLE_ID.md).

**Current Status:**
- ✅ v1.0 uses self-signed certificates (open-source standard)
- 🔄 Future: May add Apple Developer ID for notarization
- 💰 Cost: $99/year for Apple Developer Program

---

## Project Structure

```
whisper-project/
├── WhisperDictation/           # Main app source
│   ├── AppDelegate.swift       # App lifecycle & menu bar
│   ├── Models/                 # Data models
│   │   ├── AppSettings.swift   # User settings & WritingStyle enum
│   │   ├── LLMModel.swift      # Available LLM models
│   │   ├── WhisperModel.swift  # Available Whisper models
│   │   └── TranscriptionHistory.swift
│   ├── Services/               # Core functionality
│   │   ├── AudioRecorder.swift      # Microphone recording
│   │   ├── WhisperService.swift     # Speech-to-text
│   │   ├── LlamaService.swift       # LLM correction & styles
│   │   ├── HotkeyManager.swift      # Global hotkey handling
│   │   ├── TextInjector.swift       # Paste transcribed text
│   │   └── ModelDownloader.swift    # Download models
│   ├── Views/                  # SwiftUI views
│   │   ├── SettingsView.swift       # Settings window
│   │   ├── HistoryView.swift        # Transcription history
│   │   └── FirstLaunchView.swift    # Welcome screen
│   └── Resources/              # Bundled binaries
│       └── llama-server        # LLM inference server
├── whisper.cpp/               # Whisper C++ library
├── llama.cpp/                 # Llama.cpp (git submodule)
├── project.yml                # XcodeGen configuration
├── docs/                      # Documentation
└── README.md                  # User documentation
```

### Key Files for Writing Styles Feature

| File | Purpose |
|------|---------|
| `AppSettings.swift:58-98` | `WritingStyle` enum (None, Professional, Casual, Funny) |
| `LlamaService.swift:89-130` | Translation-style prompts for each style |
| `AppDelegate.swift:283-301` | Style cycling logic (Cmd+Shift+S) |
| `AppDelegate.swift:297-302` | Menu bar badge display |
| `SettingsView.swift:71-83` | Style picker UI |
| `HotkeyManager.swift:68-76` | Cmd+Shift+S hotkey detection |

---

## Contributing

### Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/whisper-project.git
   cd whisper-project
   ```
3. **Create a feature branch:**
   ```bash
   git checkout -b feature/my-awesome-feature
   ```

### Contribution Workflow

1. **Make your changes**
   - Follow Swift style conventions
   - Add comments for complex logic
   - Update documentation if needed

2. **Test your changes**
   ```bash
   # Build and run
   xcodegen generate
   xcodebuild -project WhisperDictation.xcodeproj \
     -scheme WhisperDictation \
     -configuration Debug \
     build
   
   # Test manually
   open build/Debug/WhisperDictation.app
   ```

3. **Commit with clear messages**
   ```bash
   git add .
   git commit -m "Add feature: description of what you did"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/my-awesome-feature
   ```

5. **Create Pull Request**
   - Go to GitHub
   - Click "New Pull Request"
   - Describe your changes
   - Reference any related issues

### Code Style Guidelines

**Swift:**
- Use 4 spaces for indentation
- Follow Swift naming conventions (camelCase)
- Add `// MARK:` comments for sections
- Prefer `guard` for early returns
- Use `self.` only when required

**Example:**
```swift
func cycleWritingStyle() {
    guard AppSettings.shared.useLLMCorrection else {
        print("⚠️ LLM correction not enabled")
        return
    }
    
    let oldStyle = AppSettings.shared.writingStyle
    let newStyle = oldStyle.next()
    AppSettings.shared.writingStyle = newStyle
    
    updateMenuBarIcon()
}
```

### What to Contribute

**Wanted:**
- 🐛 Bug fixes
- 📝 Documentation improvements
- 🎨 New writing styles
- 🌐 Localization (i18n)
- ✨ Feature enhancements
- 🧪 Unit tests
- 🎯 Performance improvements

**Ideas:**
- Additional writing styles (e.g., Technical, Poetic)
- Better LLM prompts for existing styles
- Custom hotkey configuration
- Voice commands (e.g., "Computer, start recording")
- Model caching improvements
- UI/UX enhancements

---

## Testing

### Manual Testing Checklist

**Core Dictation:**
- [ ] CapsLock hotkey starts/stops recording
- [ ] Audio is captured correctly
- [ ] Transcription appears at cursor
- [ ] History saves transcriptions (Cmd+Shift+H)

**Writing Styles:**
- [ ] LLM toggle enables/disables styles
- [ ] Style picker appears when LLM enabled
- [ ] Menu bar badge shows correct number (1-4)
- [ ] Cmd+Shift+S cycles styles correctly
- [ ] Each style produces appropriate output:
  - None: Basic corrections
  - Professional: Formal tone
  - Casual: Conversational tone
  - Funny: Bender-style humor

**Edge Cases:**
- [ ] Long transcriptions (>100 words)
- [ ] Questions ("Should we...?") get rephrased, not answered
- [ ] Empty audio (silence) doesn't crash
- [ ] Model switching works
- [ ] App restarts preserve settings

### Testing New Writing Styles

If you add a new style, test with these phrases:

1. **Statement:** "I need to send an email to the team"
2. **Question:** "Should we have a meeting tomorrow?"
3. **Long text:** "Hello everyone, I wanted to reach out to discuss the project timeline and see if we can coordinate a meeting to align on the next steps and deliverables"

**Expected behavior:**
- Style is applied consistently
- Questions remain questions (not answered)
- Long text doesn't get cut off
- Output maintains original meaning

### LLM Testing

Test with different model sizes:

```bash
# Test with 3B model (fast but inconsistent)
# Settings → LLM Models → Qwen2.5 3B

# Test with 7B model (recommended)
# Settings → LLM Models → Qwen2.5 7B
```

**Check for:**
- Response time (<2 seconds for 7B on M1/M2)
- Consistency (same input → similar output)
- No hallucinations or off-topic responses

---

## Release Process

### For Maintainers

#### 1. Version Bump

Update version in `WhisperDictation/Resources/Info.plist`:
```xml
<key>CFBundleShortVersionString</key>
<string>1.1.0</string>
<key>CFBundleVersion</key>
<string>2</string>
```

#### 2. Update Changelog

Create `CHANGELOG.md` entry:
```markdown
## [1.1.0] - 2026-02-15

### Added
- New "Technical" writing style for documentation
- Model caching for faster startup

### Fixed
- Style cycling issue when LLM disabled
- Memory leak in audio recorder

### Changed
- Improved prompt for Professional style
```

#### 3. Build Release

```bash
# Clean build
xcodebuild -project WhisperDictation.xcodeproj \
  -scheme WhisperDictation \
  -configuration Release \
  clean build

# Copy to desktop
cp -R build/Release/WhisperDictation.app ~/Desktop/WhisperDictation-Release.app

# Package
cd ~/Desktop
zip -r WhisperDictation-v1.1.0.zip WhisperDictation-Release.app

# Generate checksum
shasum -a 256 WhisperDictation-v1.1.0.zip > WhisperDictation-v1.1.0.zip.sha256
```

#### 4. Git Tag

```bash
git add .
git commit -m "Release v1.1.0"
git tag v1.1.0
git push origin main --tags
```

#### 5. GitHub Release

1. Go to https://github.com/c0rtexR/whisper-project/releases/new
2. Choose tag: `v1.1.0`
3. Title: `Whisper Dictation v1.1.0 - [Feature Name]`
4. Upload `.zip` file
5. Include SHA256 checksum
6. Publish release

---

## Troubleshooting

### Build Errors

**"Cannot find libwhisper.a"**
```bash
cd whisper.cpp
./build_framework.sh
```

**"Code signing failed"**
- Open project in Xcode
- Go to Signing & Capabilities
- Select your development team
- Xcode will auto-create certificate

**"llama-server not found"**
```bash
cd llama.cpp
mkdir build && cd build
cmake .. -DGGML_METAL=ON
make -j
```

### Runtime Issues

**"App cannot be opened" (Gatekeeper)**
```bash
xattr -d com.apple.quarantine /Applications/WhisperDictation.app
```

**LLM server not starting**
```bash
# Check if server is running
ps aux | grep llama-server

# Check server logs
log show --predicate 'process == "WhisperDictation"' --last 5m
```

**Hotkey not working**
- System Settings → Privacy & Security → Accessibility
- Add WhisperDictation.app
- Restart app

---

## Resources

### Documentation
- [User README](../README.md)
- [Code Signing Guide](../SIGNING_WITH_APPLE_ID.md)
- [Release Guide](../RELEASE_GUIDE.md)

### Dependencies
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - Whisper inference
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - LLM inference
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) - Project generation

### Models
- [Whisper Models](https://huggingface.co/ggerganov/whisper.cpp)
- [Qwen Models](https://huggingface.co/Qwen)
- [Llama Models](https://huggingface.co/meta-llama)

---

## Questions?

- **Issues:** https://github.com/c0rtexR/whisper-project/issues
- **Discussions:** https://github.com/c0rtexR/whisper-project/discussions
- **Pull Requests:** https://github.com/c0rtexR/whisper-project/pulls

Thank you for contributing! 🎉
