# OpenDrop

OpenDrop is a cross-platform file sharing app built with Flutter. It allows users on the same local network to discover each other using UDP broadcast and exchange files.

## Features

- Advertise presence on the local network.
- Detect other users broadcasting on the network.
- List available peers and select one to send files.
- Works on macOS, Linux and Android.
- On-screen debug log shows discovery events.
- Running with the `-debug` option prints all logs to the console.
- Display your device's IP and manually connect to another IP. Connection
  attempts show success or failure in the debug log.
- If multiple local IP addresses are detected at startup, a dialog lists each
  interface and IP so you can choose which one to use.
- After connecting, use the menu to send a file through the established link.
- When connected, the remote IP and greeting emoji are shown.
- Received files are saved in your chosen directory (defaulting to Downloads).
  Each transfer shows a progress bar with percentage and can be cancelled.
  Progress is visible on both sending and receiving ends. The app automatically
  retries sending if the connection drops until the transfer completes or is
    cancelled. Transfers now use WebRTC data channels for greater reliability
    through the `flutter_webrtc` 0.14 plugin.
- A Settings screen lets you pick the folder used to store transfers and the
  choice persists between launches.


## Getting Started

You need Flutter installed to build the app. OpenDrop requires **Flutter 3.4** or later. Run the following commands:

```bash
flutter pub get
flutter run
```

The app will display other devices running OpenDrop on the same network. Tap a peer to select a file and send it.
You can also use the link icon to enter an IP address and connect directly. Once
connected, devices automatically exchange an emoji and the "Send File"
menu option becomes enabled for sending data. On Android, ensure the device is
connected to Wi-Fi so its IP can be detected.

### Android permissions

The release version of the app requires the `INTERNET` permission to open
network sockets. Ensure the following line is present in
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```


### macOS permissions

When building for macOS the app runs inside the sandbox. The entitlements files
have been configured to allow both network client and server access. If you
modify the project, ensure `com.apple.security.network.client` and
`com.apple.security.network.server` remain enabled so discovery works correctly.
To access files chosen via the dialog and save incoming files in `Downloads`
also enable `com.apple.security.files.user-selected.read-write` and
`com.apple.security.files.downloads.read-write`.

### Stability Improvements

- Fixed a crash that occurred when the data channel was closed after the peer connection ended.
