#!/bin/bash

VERSION=$1

cat << EOL
# LibreDrop v${VERSION}

## 🎉 What's New

- First functional version tested on Android and macOS


### ✨ Features
- Cross-platform file sharing with enhanced reliability
- Improved device discovery and connection stability
- Better user interface with material design updates
- Enhanced privacy controls and transparent operations

### 🔧 Improvements
- Faster file transfer speeds with optimized WebRTC
- Better error handling and user feedback
- Reduced memory usage and improved performance
- More responsive UI across all platforms

### 🐛 Bug Fixes
- Fixed connection issues on some network configurations
- Resolved file transfer interruption problems
- Improved compatibility with older Android versions
- Fixed UI scaling issues on different screen sizes

### 📱 Platform Support
- ✅ Android 5.0+ (API 21+)
- ✅ Windows 10+ (64-bit)
- ✅ macOS 10.14+ (Mojave)
- ✅ Linux (AppImage, Snap, Flatpak)
- 🔄 iOS (Coming Soon)

### 🔒 Privacy & Security
- Zero data collection - completely private
- Local network only - no internet required
- Open source and auditable
- End-to-end encrypted transfers

## 📥 Installation

### Quick Install
- **Android**: Download APK below or get from F-Droid
- **Windows**: Download .exe installer
- **macOS**: Download .dmg package
- **Linux**: Download AppImage for universal compatibility



## 🚀 Getting Started

1. Install LibreDrop on devices you want to connect
2. Connect both devices to the same Wi-Fi network
3. Open LibreDrop and select files to share
4. Choose target device and confirm transfer

## 📚 Resources

- 🌐 **Website**: https://libredrop.org
- 📖 **Documentation**: https://libredrop.org/docs
- 💬 **Community**: https://github.com/pablojavier/libredrop/discussions
- 🐛 **Issues**: https://github.com/pablojavier/libredrop/issues

## 🙏 Contributors

Thank you to everyone who contributed to this release!

---

**Full Changelog**: https://github.com/pablojavier/libredrop/compare/v$(echo $VERSION | awk -F. '{print $1"."$2"."$3-1}')...v$VERSION
EOL
