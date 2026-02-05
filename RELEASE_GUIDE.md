# Release Guide

## 1. Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `whisper-dictation`
3. Description: "System-wide voice dictation for macOS with AI-powered writing styles"
4. Choose: Public
5. **DO NOT** initialize with README (we already have one)
6. Click "Create repository"

## 2. Push to GitHub

```bash
# Add remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/whisper-dictation.git

# Push code
git branch -M main
git push -u origin main
```

## 3. Create a Release

### On GitHub:
1. Go to your repository page
2. Click "Releases" (right sidebar)
3. Click "Create a new release"

### Release Details:
- **Tag**: `v1.0.0`
- **Title**: `Whisper Dictation v1.0.0 - Writing Styles Feature`
- **Description**:
```markdown
## 🎉 First Release: Writing Styles Feature

Transform your voice dictations with 4 different writing styles!

### ✨ New Features
- **Writing Styles**: None, Professional, Casual, Funny (Bender)
- **Menu Bar Badge**: Shows current style number (1-4)
- **Quick Switching**: Cmd+Shift+S hotkey to cycle styles
- **Visual Feedback**: Status menu displays current style name

### 🚀 Core Features
- System-wide voice dictation using OpenAI Whisper
- Local processing with GPU acceleration (Metal)
- Multiple Whisper models (tiny to large-v3)
- Optional LLM-based text correction
- Transcription history with keyboard shortcut
- Toggle or Hold-to-Record modes

### 📋 Requirements
- macOS 13.0+
- Apple Silicon (M1/M2/M3) or Intel Mac
- 8GB+ RAM recommended for Writing Styles (7B model)

### 📥 Installation

**Manual Install:**
1. Download `WhisperDictation-v1.0.0.zip`
2. Unzip and move to `/Applications/`
3. Right-click → Open (first launch only)
4. Grant Microphone and Accessibility permissions
5. Download models through Settings

**Auto-Update:**
- Existing users will be notified automatically
- Click "Download & Install" in the update prompt
- Or check manually: Menu Bar → Check for Updates...

### 🔒 Integrity Verification
**SHA256 Checksum:**
```
[paste checksum here]
```

Verify manually:
```bash
shasum -a 256 WhisperDictation-v1.0.0.zip
```

### 🎨 Using Writing Styles
1. Settings → General → Enable "Use LLM to correct transcriptions"
2. Settings → LLM Models → Download "Qwen2.5 7B" (recommended)
3. Settings → General → Select writing style
4. Or press Cmd+Shift+S to cycle styles quickly!

### 🐛 Known Issues
- Writing Styles require 7B model for best results
- Smaller models (0.5B-3B) may produce inconsistent results
- First LLM request takes a few seconds (model loading)

### 📝 Credits
Built with whisper.cpp, llama.cpp, and Qwen models.
```

4. **Generate SHA256 Checksum**:

The auto-updater verifies downloads using SHA256 checksums. Generate and include in release notes:

```bash
# Navigate to where you saved the zip file
cd ~/Desktop

# Generate checksum
shasum -a 256 WhisperDictation-v1.0.0.zip

# Output example:
# abc123def456789... WhisperDictation-v1.0.0.zip
```

5. **Upload**:
   - Drag and drop `~/Desktop/WhisperDictation-v1.0.0.zip`
   - Add SHA256 checksum to release notes in this format:
     ```
     **SHA256 Checksum:**
     ```
     abc123def456789...
     ```
     ```
   - This checksum is used by the auto-updater to verify download integrity

6. Click "Publish release"

## 4. Add Release Badge to README

Add this to the top of your README.md:

```markdown
[![Release](https://img.shields.io/github/v/release/YOUR_USERNAME/whisper-dictation)](https://github.com/YOUR_USERNAME/whisper-dictation/releases)
[![Downloads](https://img.shields.io/github/downloads/YOUR_USERNAME/whisper-dictation/total)](https://github.com/YOUR_USERNAME/whisper-dictation/releases)
[![License](https://img.shields.io/github/license/YOUR_USERNAME/whisper-dictation)](LICENSE)
```

## 5. Optional: Add Screenshots

Take screenshots of:
1. Menu bar with badge (1-4)
2. Settings window with Writing Style picker
3. History window showing different styles

Upload to an `assets/` folder in your repo and reference in README.

## 6. Share!

Share on:
- Reddit: r/MacOS, r/MacApps, r/LocalLLaMA
- Hacker News
- Twitter/X
- Product Hunt

## Future Releases

For future releases:
1. Make changes and commit
2. Tag the release: `git tag v1.1.0 && git push --tags`
3. Create new Release on GitHub with updated changelog
4. Build new .app and upload as asset

## Code Signing Status

### Current Status (v1.0)
- **Self-signed** with local development certificate
- Users will see "unidentified developer" warning
- **This is normal for open-source Mac apps** (Homebrew, Rectangle, etc.)
- Instructions provided in README for safe installation

### Advantages of Current Approach
- ✅ Free (no $99/year Apple Developer ID)
- ✅ Full source code transparency
- ✅ Users can build from source to verify
- ✅ Common practice for open-source projects

### Future: Apple Developer ID (Optional)
If you want to eliminate warnings:
1. Enroll in Apple Developer Program ($99/year)
2. Follow `SIGNING_WITH_APPLE_ID.md` guide
3. Rebuild and notarize the app
4. Release v1.1 with "Now notarized!" in changelog

For v1.0, the current approach is perfectly acceptable!
