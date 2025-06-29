# Telodoy

Telodoy is a cross-platform file sharing app built with Flutter. It allows users on the same local network to discover each other using UDP broadcast and exchange files.

## Features

- Advertise presence on the local network.
- Detect other users broadcasting on the network.
- List available peers and select one to send files.
- Works on macOS, Linux and Android.

## Getting Started

You need Flutter installed to build the app. Telodoy requires **Flutter 3.4** or later. Run the following commands:

```bash
flutter pub get
flutter run
```

The app will display other devices running Telodoy on the same network. Tap a peer to select a file and send it.

## Development

Telodoy requires **Flutter 3.22 or newer**. Install the NDK version `27.0.12077973` through Android Studio's SDK manager or via `sdkmanager` before building for Android.

To keep the codebase consistent, format and analyze before committing:

```bash
dart format .
flutter analyze
```
