#!/bin/bash

set -e

EXTENSION_NAME="gba-aseprite-shader"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect Aseprite extensions directory based on OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    EXTENSIONS_DIR="$HOME/Library/Application Support/Aseprite/extensions"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    EXTENSIONS_DIR="$HOME/.config/aseprite/extensions"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    # Windows
    EXTENSIONS_DIR="$APPDATA/Aseprite/extensions"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

TARGET_DIR="$EXTENSIONS_DIR/$EXTENSION_NAME"

echo "🚀 Deploying extension..."
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"

# Create extensions directory if it doesn't exist
mkdir -p "$EXTENSIONS_DIR"

# Remove existing extension if present
if [ -d "$TARGET_DIR" ]; then
    echo "📁 Removing existing extension..."
    rm -rf "$TARGET_DIR"
fi

# Create target directory
mkdir -p "$TARGET_DIR"

# Copy extension files
echo "📋 Copying extension files..."
cp "$SOURCE_DIR/package.json" "$TARGET_DIR/"
cp "$SOURCE_DIR/extension.json" "$TARGET_DIR/"
cp "$SOURCE_DIR/gba-aseprite-shader.lua" "$TARGET_DIR/"

echo "✅ Extension deployed successfully!"

echo "⚠️ Please manually restart Aseprite to load the extension"

echo ""
echo "🎮 Edit → FX → GBA Shader"