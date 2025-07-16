#!/bin/bash

echo "🧹 Cleaning LibreDrop builds..."
echo "==============================="

# Flutter clean
echo "🔄 Running flutter clean..."
flutter clean

# Remove build outputs
echo "📁 Removing build output directories..."
rm -rf build_output/
rm -rf dist/

# Remove backup files
echo "🗑️ Removing backup files..."
find . -name "*.bak" -type f -delete

# Remove temporary files
echo "🧽 Removing temporary files..."
rm -rf .dart_tool/build/
rm -rf .flutter-plugins-dependencies

echo "✅ Cleanup complete!"
echo ""
echo "💡 To rebuild everything, run:"
echo "   flutter pub get"
echo "   ./scripts/build_all_platforms.sh"
