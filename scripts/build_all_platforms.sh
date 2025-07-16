#!/bin/bash

set -e

echo "🔨 Building LibreDrop for All Platforms..."
echo "========================================="

BUILD_DIR="build_output"
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')

echo "📦 Building version: $VERSION"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Create output directory
mkdir -p "$BUILD_DIR"

# Test build first
echo "🧪 Running tests before building..."
flutter test
if [[ $? -ne 0 ]]; then
    echo "❌ Tests failed. Fix tests before building."
    exit 1
fi

echo "✅ Tests passed"

# Android
echo "🤖 Building Android..."
flutter build apk --release --split-per-abi
cp build/app/outputs/apk/release/app-arm64-v8a-release.apk "$BUILD_DIR/libredrop-v$VERSION-android-arm64.apk"
cp build/app/outputs/apk/release/app-armeabi-v7a-release.apk "$BUILD_DIR/libredrop-v$VERSION-android-arm.apk"
if [[ -f "build/app/outputs/apk/release/app-x86_64-release.apk" ]]; then
    cp build/app/outputs/apk/release/app-x86_64-release.apk "$BUILD_DIR/libredrop-v$VERSION-android-x64.apk"
fi
echo "✅ Android build complete"

# Windows (if on Windows or with cross-compilation)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || command -v flutter.bat &> /dev/null; then
    echo "🪟 Building Windows..."
    flutter config --enable-windows-desktop
    flutter build windows --release
    
    # Create zip archive
    cd build/windows/runner/Release
    if command -v zip &> /dev/null; then
        zip -r "../../../../$BUILD_DIR/libredrop-v$VERSION-windows.zip" .
    else
        echo "⚠️ zip not found, creating tar.gz instead"
        tar -czf "../../../../$BUILD_DIR/libredrop-v$VERSION-windows.tar.gz" .
    fi
    cd ../../../../
    echo "✅ Windows build complete"
else
    echo "⚠️ Skipping Windows build (not on Windows)"
fi

# macOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Building macOS..."
    flutter config --enable-macos-desktop
    flutter build macos --release
    
    # Create zip archive
    cd build/macos/Build/Products/Release
    zip -r "../../../../../$BUILD_DIR/libredrop-v$VERSION-macos.zip" libredrop.app
    cd ../../../../../
    echo "✅ macOS build complete"
else
    echo "⚠️ Skipping macOS build (not on macOS)"
fi

# Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🐧 Building Linux..."
    
    # Check for required dependencies
    if ! command -v ninja &> /dev/null; then
        echo "📦 Installing Linux build dependencies..."
        sudo apt-get update
        sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
    fi
    
    flutter config --enable-linux-desktop
    flutter build linux --release
    
    # Create tar.gz archive
    cd build/linux/x64/release/bundle
    tar -czf "../../../../../$BUILD_DIR/libredrop-v$VERSION-linux.tar.gz" .
    cd ../../../../../
    echo "✅ Linux build complete"
else
    echo "⚠️ Skipping Linux build (not on Linux)"
fi

# Web build (for testing)
echo "🌐 Building Web..."
flutter build web --release
cd build/web
tar -czf "../../$BUILD_DIR/libredrop-v$VERSION-web.tar.gz" .
cd ../../
echo "✅ Web build complete"

echo ""
echo "🎉 Build Complete!"
echo "================="
echo "📁 Output directory: $BUILD_DIR"
echo "📦 Built files:"
ls -la "$BUILD_DIR"
echo ""
echo "🧪 Test the builds before releasing!"
echo "💡 To create a release, run: ./scripts/prepare_release.sh"
