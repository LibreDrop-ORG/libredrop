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
sed -i.bak "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
echo "✅ Updated pubspec.yaml"

# Update version in dart files if they exist
if [[ -f "lib/constants/app_info.dart" ]]; then
    sed -i.bak "s/static const String version = .*/static const String version = '$NEW_VERSION';/" lib/constants/app_info.dart
    echo "✅ Updated app_info.dart"
fi

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
\\n### Added\\\n- [Add new features here]\\\n\\n### Changed\\\n- [Add changes here]\\\n\\n### Fixed\\\n- [Add bug fixes here]\\\n\\n" CHANGELOG.md
fi

echo "✅ Updated CHANGELOG.md"

# The following steps (tests, build, commit, tag, push) will be handled by GitHub Actions workflow.
# This script only prepares the local files.

echo ""
echo "🎉 Release v$NEW_VERSION prepared successfully locally!"
echo "================================="
echo ""
echo "📋 Next steps:"
echo "1. ✅ Version updated in pubspec.yaml and app_info.dart"
echo "2. ✅ Changelog updated"
echo "3. 🔄 Commit these changes and push to GitHub to trigger the Release workflow."
echo "   (The Release workflow will handle testing, building, tagging, and creating the GitHub Release)"
echo ""