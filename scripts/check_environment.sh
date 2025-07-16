#!/bin/bash

echo "🔍 Checking LibreDrop Development Environment..."
echo "=============================================="

# Check Flutter
echo "📱 Checking Flutter..."
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -1)
    echo "✅ Flutter found: $FLUTTER_VERSION"
    
    # Check Flutter doctor
    echo "🏥 Running Flutter doctor..."
    flutter doctor --no-version-check
else
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Check Git
echo "📝 Checking Git..."
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version)
    echo "✅ Git found: $GIT_VERSION"
    
    # Check if we're in a git repository
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "✅ Git repository detected"
        
        # Check remote
        if git remote get-url origin > /dev/null 2>&1; then
            ORIGIN=$(git remote get-url origin)
            echo "✅ Remote origin: $ORIGIN"
        else
            echo "⚠️ No remote origin configured"
        fi
    else
        echo "❌ Not in a git repository"
        exit 1
    fi
else
    echo "❌ Git not found. Please install Git first."
    exit 1
fi

# Check project structure
echo "📁 Checking project structure..."
if [[ -f "pubspec.yaml" ]]; then
    echo "✅ pubspec.yaml found"
    
    PROJECT_NAME=$(grep '^name:' pubspec.yaml | sed 's/name: //')
    echo "📦 Project name: $PROJECT_NAME"
    
    CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
    echo "🏷️ Current version: $CURRENT_VERSION"
else
    echo "❌ pubspec.yaml not found. Are you in a Flutter project?"
    exit 1
fi

# Check for required directories
REQUIRED_DIRS=("lib" "android" "windows" "macos" "linux")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "✅ $dir/ directory found"
    else
        echo "⚠️ $dir/ directory not found (this platform may not be supported)"
    fi
done

# Check if workflows exist
echo "⚙️ Checking GitHub Actions setup..."
if [[ -f ".github/workflows/ci.yml" ]]; then
    echo "✅ CI workflow found"
else
    echo "⚠️ CI workflow not found"
fi

if [[ -f ".github/workflows/release.yml" ]]; then
    echo "✅ Release workflow found"
else
    echo "⚠️ Release workflow not found"
fi

# Check scripts
echo "📝 Checking release scripts..."
if [[ -f "scripts/prepare_release.sh" ]]; then
    echo "✅ Release preparation script found"
else
    echo "⚠️ Release preparation script not found"
fi

if [[ -f "scripts/build_all_platforms.sh" ]]; then
    echo "✅ Build script found"
else
    echo "⚠️ Build script not found"
fi

echo ""
echo "🎯 Environment Check Complete!"
echo "============================="

# Summary
echo "📋 Summary:"
echo "   Flutter: ✅"
echo "   Git: ✅"
echo "   Project: ✅"
echo ""
echo "🚀 Ready to build LibreDrop!"
echo "💡 Next steps:"
echo "   - Run tests: flutter test"
echo "   - Build for current platform: flutter build [platform]"
echo "   - Create release: ./scripts/prepare_release.sh"
