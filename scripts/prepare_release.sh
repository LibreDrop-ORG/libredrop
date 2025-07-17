#!/bin/bash

set -e

echo "🚀 Preparing LibreDrop Release..."
echo "================================="

# Check if we're in the right directory
if [[ ! -f "pubspec.yaml" ]]; then
    echo "❌ Error: Not in Flutter project directory"
    exit 1
fi

# Get current version
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
echo "📦 Current version: $CURRENT_VERSION"

# Ask for new version
NEW_VERSION=$1

# Validate version format
if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Use semantic versioning (e.g., 1.0.1)"
    exit 1
fi

echo "🔍 Preparing release v$NEW_VERSION..."

# Update pubspec.yaml
sed -i.bak "s/^version: .*/version: $NEW_VERSION+1/" pubspec.yaml
echo "✅ Updated pubspec.yaml"

# Update version in dart files if they exist
if [[ -f "lib/constants/app_info.dart" ]]; then
    sed -i.bak "s/static const String version = .*/static const String version = '$NEW_VERSION';/" lib/constants/app_info.dart
    echo "✅ Updated app_info.dart"
fi

# Run tests
echo "🧪 Running tests..."
flutter test
if [[ $? -ne 0 ]]; then
    echo "❌ Tests failed. Please fix before releasing."
    exit 1
fi

# Build for verification
echo "🔨 Building for verification..."
flutter build apk --release
if [[ $? -ne 0 ]]; then
    echo "❌ Build failed. Please fix before releasing."
    exit 1
fi

echo "✅ Build successful"

# Create changelog entry
echo "📝 Updating CHANGELOG.md..."
if [[ ! -f "CHANGELOG.md" ]]; then
    cat > CHANGELOG.md << EOL
# Changelog

All notable changes to LibreDrop will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [$NEW_VERSION] - $(date +%Y-%m-%d)

### Added
- Initial release of LibreDrop
- Cross-platform file sharing functionality
- Privacy-first design with local-only transfers
- Support for Android, Windows, macOS, and Linux

### Changed
- N/A

### Fixed
- N/A

### Security
- All transfers are encrypted and local-only
EOL
else
    # Add new version to existing changelog
    sed -i.bak "/## \[Unreleased\]/a\
\n## [$NEW_VERSION] - $(date +%Y-%m-%d)\\
\\
### Added\\
- [Add new features here]\\
\\
### Changed\\
- [Add changes here]\\
\\
### Fixed\\
- [Add bug fixes here]\\
\\
" CHANGELOG.md
fi

echo "✅ Updated CHANGELOG.md"

# Commit changes
echo "📝 Committing changes..."
git add pubspec.yaml CHANGELOG.md
if [[ -f "lib/constants/app_info.dart" ]]; then
    git add lib/constants/app_info.dart
fi

git commit -m "Prepare release v$NEW_VERSION

- Update version to $NEW_VERSION
- Update changelog
- Ready for release"

echo "✅ Changes committed"

# Create and push tag
echo "🏷️  Creating and pushing tag..."
git tag "v$NEW_VERSION"
git push origin main
git push origin "v$NEW_VERSION"

echo ""
echo "🎉 Release v$NEW_VERSION prepared successfully!"
echo "================================="
echo ""
echo "📋 Next steps:"
echo "1. ✅ Version updated and committed"
echo "2. ✅ Tag created and pushed"
echo "3. 🔄 GitHub Actions will now build and release automatically"
echo "4. 📱 Binaries will be available at: https://github.com/pablojavier/libredrop/releases"
echo "5. 🌐 Website will automatically detect the new version"
echo ""
echo "🕐 Estimated build time: 15-20 minutes"
echo "📝 Edit CHANGELOG.md to add specific changes before next release"
