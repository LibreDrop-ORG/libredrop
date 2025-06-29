# Telodoy

Telodoy is a cross-platform file sharing app built with Flutter. It allows users on the same local network to discover each other using UDP broadcast and exchange files.

## Features

- Advertise presence on the local network.
- Detect other users broadcasting on the network.
- List available peers and select one to send files.
- Works on macOS, Linux and Android.
- On-screen debug log shows discovery events.
- Display your device's IP and manually connect to another IP. Connection
  attempts show success or failure in the debug log.


## Getting Started

You need Flutter installed to build the app. Telodoy requires **Flutter 3.4** or later. Run the following commands:

```bash
flutter pub get
flutter run
```

The app will display other devices running Telodoy on the same network. Tap a peer to select a file and send it.
You can also use the link icon to enter an IP address and connect directly. Once
connected, devices automatically exchange an emoji. On Android, ensure the
device is connected to Wi-Fi so its IP can be detected.


### macOS permissions

When building for macOS the app runs inside the sandbox. The entitlements files
have been configured to allow both network client and server access. If you
modify the project, ensure `com.apple.security.network.client` and
`com.apple.security.network.server` remain enabled so discovery works correctly.
