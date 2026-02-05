#!/bin/bash

# Build whisper.cpp with Metal acceleration for Apple Silicon
# This script clones whisper.cpp and builds it as a static library

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/whisper.cpp"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$SCRIPT_DIR/lib"

echo "Building whisper.cpp with Metal acceleration..."

# Clone whisper.cpp if not already present
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Cloning whisper.cpp..."
    git clone https://github.com/ggerganov/whisper.cpp.git "$SOURCE_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake - enable Metal for Apple Silicon
cmake "$SOURCE_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DWHISPER_METAL=ON \
    -DWHISPER_COREML=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

# Build
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

# Install
cmake --install . --config Release

echo "✅ whisper.cpp built successfully!"
echo "Library location: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "1. Add libwhisper.a to your Xcode project"
echo "2. Add the whisper.cpp headers to your header search paths"
echo "3. Link against Metal framework"
