// LibreDrop - Local network file sharing app
// Copyright (C) 2025 Pablo Javier Etcheverry
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'webrtc_service.dart';
import 'settings_page.dart';
import 'settings_service.dart';
import 'debug.dart';

const int connectionPort = 5678;

Future<String?> getLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: true,
    );
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.isLoopback &&
            !addr.address.startsWith('169.254')) {
          return addr.address;
        }
      }
    }
  } catch (_) {
    // ignore and return null
  }
  return null;
}

Future<String?> chooseLocalIp(BuildContext context) async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: true,
    );
    final options = <MapEntry<String, String>>[];
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 &&
            !addr.isLoopback &&
            !addr.address.startsWith('169.254')) {
          options.add(MapEntry(interface.name, addr.address));
        }
      }
    }
    if (options.isEmpty) return null;
    if (options.length == 1) return options.first.value;
    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select IP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (e) => ListTile(
                    title: Text(e.value),
                    subtitle: Text(e.key),
                    onTap: () => Navigator.of(context).pop(e.value),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  } catch (_) {
    return null;
  }
}

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: avoid_print
  print('main args: $args');
  String? instanceName;
  String? projectRootPath;

  // Read debug mode and instance name from --dart-define
  const bool debugModeEnabled = bool.fromEnvironment('DEBUG_MODE');
  const String instanceNameDefine = String.fromEnvironment('INSTANCE_NAME');

  if (instanceNameDefine.isNotEmpty) {
    instanceName = instanceNameDefine;
  } else {
    instanceName = Platform.isAndroid ? 'android' : 'macos';
  }

  // Read project root path from --dart-define (primarily for macOS)
  const String projectRootDefine = String.fromEnvironment('PROJECT_ROOT');
  if (projectRootDefine.isNotEmpty) {
    projectRootPath = projectRootDefine;
  }

  if (debugModeEnabled) {
    // Only pass projectRootPath if not on Android, due to sandboxing
    if (Platform.isAndroid) {
      initializeFileLogger(
          instanceName); // Android will use app support directory
    } else {
      initializeFileLogger(instanceName, logDirectoryPath: projectRootPath);
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibreDrop',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class Peer {
  final InternetAddress address;
  final int port;
  final String name;
  final String type; // e.g., 'android', 'macos', 'linux', 'windows'

  Peer(this.address, this.port, {required this.name, required this.type});
}

class DiscoveryService {
  static const int broadcastPort = 4567;
  static const String messagePrefix = 'LIBREDROP:';
  final String deviceName;
  final String deviceType;

  DiscoveryService({
    this.onLog,
    required String localIp,
    required this.deviceName,
    required this.deviceType,
    this.knownPeers,
  }) : _localIp = localIp {
    debugLog('DiscoveryService initialized with local IP: $_localIp');
    if (knownPeers != null) {
      for (final ip in knownPeers!) {
        final peer = Peer(
          InternetAddress(ip),
          connectionPort,
          name: 'Unknown', // Default name for manually added peers
          type: 'Unknown', // Default type for manually added peers
        );
        if (peer.address.address != _localIp &&
            !peers.any((p) => p.address == peer.address)) {
          peers.add(peer);
          onLog?.call('Manually added known peer ${peer.address.address}');
          debugLog('Manually added known peer ${peer.address.address}');
        }
      }
    }
  }

  final List<Peer> peers = [];
  final void Function(String)? onLog;
  final String _localIp;
  final List<String>? knownPeers;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _announceTimer;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      broadcastPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket!.broadcastEnabled = true;
    _subscription = _socket!.listen(_handleEvent);
    onLog?.call('Discovery started on port ${_socket!.port}');
    debugLog('Discovery started on port ${_socket!.port}');
    _announceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => announce(),
    );
  }

  void announce() {
    debugLog('Sending discovery announcement.');
    final message = jsonEncode({
      'prefix': messagePrefix,
      'name': deviceName,
      'type': deviceType,
    });
    _socket?.send(
      utf8.encode(message),
      InternetAddress('255.255.255.255'),
      broadcastPort,
    );
  }

  void _handleEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read && _socket != null) {
      final dg = _socket!.receive();
      if (dg == null) return;
      final rawMsg = utf8.decode(dg.data);
      try {
        final Map<String, dynamic> msg = jsonDecode(rawMsg);
        if (msg['prefix'] == messagePrefix) {
          final peer = Peer(
            dg.address,
            dg.port,
            name: msg['name'] ?? 'Unknown',
            type: msg['type'] ?? 'Unknown',
          );
          debugLog(
              'Received discovery message from ${peer.address.address} (Name: ${peer.name}, Type: ${peer.type})');
          if (peer.address.address != _localIp &&
              !peers.any((p) => p.address == peer.address)) {
            peers.add(peer);
            onLog?.call(
                'Discovered peer ${peer.name} (${peer.address.address})');
            debugLog('Added peer ${peer.address.address}');
          } else {
            debugLog(
                'Filtered out peer ${peer.address.address} (either self or already in list).');
          }
        }
      } catch (e) {
        debugLog('Received non-JSON discovery message or malformed: $rawMsg');
      }
    }
  }

  void dispose() {
    _announceTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
  }
}

class ConnectionService {
  ConnectionService({
    this.onLog,
    this.onConnected,
    this.onDisconnected,
    this.onGreeting,
    this.onFileStarted,
    this.onFileProgress,
    this.onFileReceived,
    this.onSendStarted,
    this.onSendProgress,
    this.onSendComplete,
    this.downloadsPath,
    this.onConfigComplete,
  });

  final void Function(String)? onLog;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final void Function(String)? onGreeting;
  final void Function(String, int)? onFileStarted;
  final void Function(int, int)? onFileProgress;
  final void Function(File)? onFileReceived;
  final void Function(String, int)? onSendStarted;
  final void Function(int, int)? onSendProgress;
  final VoidCallback? onSendComplete;
  String? downloadsPath;
  final void Function(int, int)? onConfigComplete;
  ServerSocket? _server;
  Socket? _socket;
  WebRTCService? _webrtc;

  String? remoteIp;
  String? remoteEmoji;

  bool get isConnected => _socket != null;

  Directory? _downloads;

  final List<int> _buffer = [];
  bool _gotGreeting = false;
  bool _receivingFile = false;
  late String _currentFileName;
  int _currentFileSize = 0;
  int _bytesReceived = 0;
  IOSink? _fileSink;

  bool _sendingFile = false;
  int _bytesSent = 0;
  int _totalToSend = 0;
  Completer<void>? _ackCompleter;

  Future<void> _initWebRTC({required bool initiator}) async {
    // WebRTC initialization - only log to console, not UI
    _webrtc?.dispose();
    _webrtc = WebRTCService(
      onSignal: (type, data) {
        final msg = jsonEncode({'type': type, 'data': data});
        debugLog('Sending WebRTC signal: $type'); // Keep for console debug
        _socket?.writeln('WEBRTC:$msg');
        _socket?.flush();
      },
      onConnected: () {}, // WebRTC connected - no UI log needed
      onDisconnected: () {}, // WebRTC disconnected - no UI log needed
      onFileStarted: onFileStarted,
      onFileProgress: onFileProgress,
      onFileReceived: onFileReceived,
      onSendStarted: onSendStarted,
      onSendProgress: onSendProgress,
      onSendComplete: onSendComplete,
      onConfigComplete: (chunkSize, bufferThreshold) {
        // These values are passed up to the HomePageState to be displayed
        // and are not stored directly in ConnectionService.
        // The WebRTCService itself will store and use the negotiated values.
        onLog?.call(
            'Negotiated config: chunkSize=$chunkSize, bufferThreshold=$bufferThreshold');
        // Propagate the config to the HomePageState
        if (onConfigComplete != null) {
          onConfigComplete!(chunkSize, bufferThreshold);
        }
      },
    );
    await _webrtc!.createPeer(initiator: initiator);
  }

  void cancelTransfer() {
    if (_sendingFile) {
      _sendingFile = false;
      _socket?.writeln('CANCEL');
      _socket?.flush();
    }
    if (_receivingFile) {
      _receivingFile = false;
      _bytesReceived = 0;
      _fileSink?.close();
      _socket?.writeln('CANCEL');
      _socket?.flush();
    }
  }

  Future<void> setDownloadPath(String? path) async {
    downloadsPath = path;
    if (path == null) {
      try {
        _downloads = await getDownloadsDirectory();
      } catch (_) {
        _downloads = Directory.systemTemp;
      }
    } else {
      _downloads = Directory(path);
      if (!await _downloads!.exists()) {
        await _downloads!.create(recursive: true);
      }
    }
  }

  Future<void> start() async {
    await setDownloadPath(downloadsPath);
    final localIp = await getLocalIp();
    if (localIp == null) {
      onLog?.call(
          'Could not determine local IP address. Server will not start.');
      debugLog('Could not determine local IP address. Server will not start.');
      return;
    }
    debugLog(
        'Attempting to bind ServerSocket to ${InternetAddress.anyIPv4.address}:$connectionPort');
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, connectionPort);
    onLog?.call('Listening on ${_server!.address.address}:$connectionPort');
    debugLog(
        'ServerSocket bound and listening on ${_server!.address.address}:${_server!.port}');
    _server!.listen(_handleClient);
    debugLog('ServerSocket listening for clients.');
  }

  void _handleClient(Socket client) async {
    debugLog(
        'Received client connection from ${client.remoteAddress.address}:${client.remotePort}');
    onLog?.call('Client connected from ${client.remoteAddress.address}');
    _socket = client;
    remoteIp = client.remoteAddress.address;
    onConnected?.call();
    await _initWebRTC(initiator: false);
    try {
      client.writeln('👋');
      client.flush();
      onLog?.call('Sent hello to ${client.remoteAddress.address}');
    } catch (e) {
      onLog?.call('Failed to send hello: $e');
    }
    client.listen(
      _onData,
      onDone: _handleDisconnect,
      onError: (e) {
        onLog?.call('Connection error: $e');
        _handleDisconnect();
      },
    );
  }

  Future<void> connect(String ip, {int retries = 3}) async {
    if (isConnected) {
      debugLog('Already connected to $remoteIp, skipping connection to $ip');
      return;
    }
    for (var i = 0; i < retries; i++) {
      try {
        final socket = await Socket.connect(
          ip,
          connectionPort,
          timeout: const Duration(seconds: 2),
        );
        onLog?.call('Connected to $ip:$connectionPort');
        _socket = socket;
        remoteIp = ip;
        onConnected?.call();
        await _initWebRTC(initiator: true);
        socket.listen(
          _onData,
          onDone: _handleDisconnect,
          onError: (e) {
            onLog?.call('Connection error: $e');
            _handleDisconnect();
          },
        );
        socket.writeln('🙂');
        await socket.flush();
        return; // Success, exit the loop
      } catch (e) {
        onLog?.call('Failed to connect to $ip:$connectionPort -> $e');
        if (i < retries - 1) {
          onLog?.call('Retrying in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          onLog?.call('Could not connect after $retries retries.');
        }
      }
    }
  }

  Future<void> sendFile(File file) async {
    if (_webrtc != null) {
      await _webrtc!.sendFile(file);
      return;
    }
    if (_socket == null) {
      onLog?.call('No active connection to send file');
      return;
    }

    _sendingFile = true;
    _bytesSent = 0;
    _totalToSend = await file.length();
    final name = file.uri.pathSegments.last;
    onSendStarted?.call(name, _totalToSend);

    while (_sendingFile) {
      try {
        onLog?.call('Sending file ${file.path}');
        _socket!.write('FILE:$name:$_totalToSend\n');
        const chunkSize = 16 * 1024;
        final raf = await file.open();
        try {
          while (_bytesSent < _totalToSend) {
            if (!_sendingFile) break;
            final remaining = _totalToSend - _bytesSent;
            final bytes = await raf.read(min(chunkSize, remaining));
            if (bytes.isEmpty) break;
            _socket!.add(bytes);
            _bytesSent += bytes.length;
            onSendProgress?.call(_bytesSent, _totalToSend);
          }
          await _socket!.flush();
        } finally {
          await raf.close();
        }
        _ackCompleter = Completer<void>();
        await _ackCompleter!.future;
        _sendingFile = false;
      } catch (e) {
        onLog?.call('Send failed: $e, retrying...');
        await Future.delayed(const Duration(seconds: 1));
        if (_socket == null && remoteIp != null) {
          await connect(remoteIp!);
        }
      }
    }
    if (!_sendingFile) {
      onSendComplete?.call();
    }
  }

  void _handleDisconnect() {
    if (_receivingFile) {
      _fileSink?.add(_buffer);
      _bytesReceived += _buffer.length;
      _buffer.clear();
      _fileSink?.flush();
      _fileSink?.close();
      final file = File('${_downloads?.path ?? ''}/$_currentFileName');
      onFileReceived?.call(file);
      _receivingFile = false;
      _bytesReceived = 0;
    } else {
      _fileSink?.close();
    }
    _socket?.destroy();
    _socket = null;
    _webrtc?.dispose();
    _webrtc = null;
    onDisconnected?.call();
    onLog?.call('Connection closed');

    if (_sendingFile &&
        (_ackCompleter != null && !_ackCompleter!.isCompleted)) {
      // try to reconnect and resend
      if (remoteIp != null) {
        connect(remoteIp!);
      }
    }
  }

  void _onData(Uint8List data) async {
    _buffer.addAll(data);
    while (true) {
      if (_receivingFile) {
        final remaining = _currentFileSize - _bytesReceived;
        if (_buffer.length < remaining) {
          _fileSink?.add(_buffer);
          _bytesReceived += _buffer.length;
          onFileProgress?.call(_bytesReceived, _currentFileSize);
          _buffer.clear();
          return;
        } else {
          _fileSink?.add(_buffer.sublist(0, remaining));
          _bytesReceived += remaining;
          onFileProgress?.call(_bytesReceived, _currentFileSize);
          await _fileSink?.flush();
          await _fileSink?.close();
          final file = File('${_downloads?.path ?? ''}/$_currentFileName');
          onFileReceived?.call(file);
          _socket?.writeln('ACK');
          await _socket?.flush();
          _buffer.removeRange(0, remaining);
          _receivingFile = false;
          _bytesReceived = 0;
          continue;
        }
      }

      final newlineIndex = _buffer.indexOf(10); // '\n'
      if (newlineIndex == -1) {
        return;
      }
      final line = utf8.decode(_buffer.sublist(0, newlineIndex));
      _buffer.removeRange(0, newlineIndex + 1);

      bool handled = false;
      if (!_gotGreeting) {
        remoteEmoji = line.trim();
        _gotGreeting = true;
        onGreeting?.call(remoteEmoji!);
        handled = true;
      } else if (line.startsWith('FILE:')) {
        final parts = line.split(':');
        if (parts.length == 3) {
          _currentFileName = parts[1];
          _currentFileSize = int.tryParse(parts[2]) ?? 0;
          final file = File('${_downloads?.path ?? ''}/$_currentFileName');
          _fileSink = file.openWrite();
          _receivingFile = true;
          onFileStarted?.call(_currentFileName, _currentFileSize);
        }
        handled = true;
      } else if (line.startsWith('WEBRTC:')) {
        final msg = jsonDecode(line.substring(7));
        final type = msg['type'] as String;
        final data = Map<String, dynamic>.from(msg['data'] as Map);
        debugLog('Received WebRTC signal: $type');
        await _webrtc?.handleSignal(type, data);
        handled = true;
      } else if (line.trim() == 'ACK' && _ackCompleter != null) {
        _ackCompleter?.complete();
        _ackCompleter = null;
        handled = true;
      } else if (line.trim() == 'CANCEL') {
        _sendingFile = false;
        _receivingFile = false;
        _ackCompleter?.completeError('cancelled');
        handled = true;
      }

      if (!handled) {
        // Only log general messages to UI, not WebRTC signaling
        onLog?.call('Received: $line');
      }
    }
  }

  void dispose() {
    _server?.close();
    _fileSink?.close();
    _socket?.destroy();
    _webrtc?.dispose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _FileTransfer {
  _FileTransfer({
    required this.name,
    required this.size,
    required this.sending,
  });

  final String name;
  final int size;
  final bool sending;
  String? path;
  int transferred = 0;
  bool cancelled = false;

  double get progress => size == 0 ? 0 : transferred / size;
  int get percentage => (progress * 100).clamp(0, 100).toInt();
}

class _HomePageState extends State<HomePage> {
  DiscoveryService? _discovery;
  late final ConnectionService _connection;
  late final SettingsService _settings;
  bool _connected = false;
  String? _localIp;
  String? _remoteIp;
  String? _remoteEmoji;
  String? _downloadsPath;
  final List<_FileTransfer> _transfers = [];
  _FileTransfer? _activeReceiveTransfer;
  _FileTransfer? _activeSendTransfer;
  final List<String> _logs = [];
  int? _negotiatedChunkSize;
  int? _negotiatedBufferThreshold;
  bool _isRefreshing = false;
  

  

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _connection = ConnectionService(
      onLog: _addLog,
      onConnected: () => setState(() => _connected = true),
      onDisconnected: () {
        setState(() {
          _connected = false;
          _remoteEmoji = null;
          _remoteIp = null;
          _activeReceiveTransfer = null;
          _activeSendTransfer = null;
        });
      },
      onGreeting: (e) {
        setState(() {
          _remoteEmoji = e;
          _remoteIp = _connection.remoteIp;
        });
      },
      onFileStarted: (name, size) {
        setState(() {
          _activeReceiveTransfer = _FileTransfer(
            name: name,
            size: size,
            sending: false,
          );
          _transfers.add(_activeReceiveTransfer!);
        });
      },
      onFileProgress: (r, t) {
        setState(() {
          if (_activeReceiveTransfer != null) {
            _activeReceiveTransfer!.transferred = r;
          }
        });
      },
      onFileReceived: (f) {
        setState(() {
          if (_activeReceiveTransfer != null) {
            _activeReceiveTransfer!
              ..path = f.path
              ..transferred = _activeReceiveTransfer!.size;
            _activeReceiveTransfer = null;
          }
        });
        _addLog('Saved file ${f.path}');
      },
      onSendStarted: (name, size) {
        setState(() {
          _activeSendTransfer = _FileTransfer(
            name: name,
            size: size,
            sending: true,
          );
          _transfers.add(_activeSendTransfer!);
        });
      },
      onSendProgress: (s, t) {
        setState(() {
          if (_activeSendTransfer != null) {
            _activeSendTransfer!.transferred = s;
          }
        });
      },
      onSendComplete: () {
        setState(() {
          if (_activeSendTransfer != null) {
            _activeSendTransfer!.transferred = _activeSendTransfer!.size;
            _activeSendTransfer = null;
          }
        });
      },
      onConfigComplete: (chunkSize, bufferThreshold) {
        setState(() {
          _negotiatedChunkSize = chunkSize;
          _negotiatedBufferThreshold = bufferThreshold;
        });
      },
    );

    _settings.loadDownloadPath().then((p) async {
      await _connection.setDownloadPath(p);
      setState(() {
        _downloadsPath = p;
      });
      _connection.start();
    });

    

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ip = await chooseLocalIp(context);
      if (ip == null) {
        _addLog('Could not determine local IP. Discovery will not start.');
        // Optionally, show an error to the user
        return;
      }
      setState(() {
        _localIp = ip;
      });

      String deviceName = Platform.localHostname;
      String deviceType = Platform.operatingSystem;

      if (Platform.isAndroid) {
        _discovery = DiscoveryService(
          onLog: _addLog,
          localIp: _localIp!,
          deviceName: deviceName,
          deviceType: deviceType,
          knownPeers: ['10.0.2.2'],
        );
        _addLog('Android detected, trying to connect to host');
        await _connection.connect('10.0.2.2');
      } else {
        _discovery = DiscoveryService(
          onLog: _addLog,
          localIp: _localIp!,
          deviceName: deviceName,
          deviceType: deviceType,
        );
      }
      _discovery!.start();
      setState(() {}); // Refresh UI after discovery starts
    });
  }

main
  @override
  void dispose() {
    _discovery?.dispose();
    _connection.dispose();
    
    disposeFileLogger();
    super.dispose();
  }

  void _addLog(String msg) {
    if (!mounted) return;
    debugLog(msg);
    
    // Filter out WEBRTC and other debug messages from UI
    final upperMsg = msg.toUpperCase();
    if (upperMsg.startsWith('WEBRTC') || 
        upperMsg.contains('WEBRTC SIGNAL') ||
        upperMsg.contains('WEBRTC CONNECTED') ||
        upperMsg.contains('WEBRTC DISCONNECTED')) {
      return; // Don't add to UI logs
    }
    
    setState(() {
      _logs.add(msg);
    });
  }

  Future<void> _pickAndSendFile({Peer? peer, File? fileToSend}) async {
    File? file;
    if (fileToSend != null) {
      file = fileToSend;
    } else {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        file = File(result.files.single.path!);
      }
    }

    if (file != null) {
      if (peer != null) {
        _sendFileToPeer(file, peer);
      } else if (_connection.isConnected) {
        await _connection.sendFile(file);
      } else {
        _addLog('Select a peer to send the file to.');
      }
    }
  }

  Future<void> _sendFileToPeer(File file, Peer peer) async {
    if (!_connection.isConnected ||
        _connection.remoteIp != peer.address.address) {
      await _connection.connect(peer.address.address);
    }
    if (_connection.isConnected) {
      await _connection.sendFile(file);
    } else {
      _addLog('Could not connect to ${peer.address.address} to send file.');
    }
  }

  Future<void> _promptAndConnect() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ip = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to IP'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter IP address'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an IP address';
              }
              final ipRegex =
                  RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
              if (!ipRegex.hasMatch(value)) {
                return 'Please enter a valid IPv4 address';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (ip != null && ip.isNotEmpty) {
      await _connection.connect(ip);
    }
  }

  Future<void> _refreshPeers() async {
    setState(() {
      _isRefreshing = true;
      _discovery?.peers.clear();
    });
    _discovery?.announce();
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_localIp ?? 'LibreDrop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final newPath = await Navigator.of(context).push<String?>(
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    currentPath: _downloadsPath,
                  ),
                ),
              );
              if (newPath != null) {
                await _settings.saveDownloadPath(newPath);
                await _connection.setDownloadPath(newPath);
                setState(() {
                  _downloadsPath = newPath;
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          _buildPeerList(),
          _buildTransferList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSendFile,
        label: const Text('Send File'),
        icon: const Icon(Icons.send),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final statusText =
        _connected ? 'Connected to $_remoteEmoji $_remoteIp' : 'Not Connected';
    final configText = _negotiatedChunkSize != null
        ? ' | WebRTC: chunk $_negotiatedChunkSize, buffer $_negotiatedBufferThreshold'
        : '';
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(statusText + configText,
          style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _buildPeerList() {
    return Expanded(
      flex: 2,
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              title: const Text('LibreDrop Peers'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Connect to IP',
                    onPressed: _promptAndConnect,
                  ),
                  IconButton(
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: 'Refresh Peers',
                    onPressed: _isRefreshing ? null : _refreshPeers,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _discovery == null || _discovery!.peers.isEmpty
                  ? const Center(child: Text('Scanning for peers...'))
                  : ListView.builder(
                      itemCount: _discovery!.peers.length,
                      itemBuilder: (context, index) {
                        final peer = _discovery!.peers[index];
                        return ListTile(
                          leading: Icon(
                            switch (peer.type) {
                              'android' => Icons.android,
                              'macos' => Icons.laptop_mac,
                              'linux' => Icons.computer,
                              'windows' => Icons.laptop_windows,
                              _ => Icons.device_unknown,
                            },
                          ),
                          title: Text(peer.name),
                          subtitle: Text(peer.address.address),
                          onTap: () =>
                              _connection.connect(peer.address.address),
                          trailing: IconButton(
                            icon: const Icon(Icons.send_to_mobile),
                            onPressed: () => _pickAndSendFile(peer: peer),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferList() {
    return Expanded(
      flex: 4,
      child: Card(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          children: [
            const ListTile(title: Text('File Transfers')),
            Expanded(
              child: _transfers.isEmpty
                  ? const Center(child: Text('No transfers yet.'))
                  : ListView.builder(
                      itemCount: _transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = _transfers.reversed.toList()[index];
                        final isSending = transfer.sending;
                        final isActive = transfer == _activeReceiveTransfer ||
                            transfer == _activeSendTransfer;
                        final isDone =
                            transfer.transferred == transfer.size && !isActive;

                        return ListTile(
                          leading:
                              Icon(isSending ? Icons.upload : Icons.download),
                          title: Text(transfer.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(transfer.transferred / 1024 / 1024).toStringAsFixed(2)} / ${(transfer.size / 1024 / 1024).toStringAsFixed(2)} MB',
                              ),
                              if (!isDone)
                                LinearProgressIndicator(
                                    value: transfer.progress),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isDone && !isSending && transfer.path != null)
                                IconButton(
                                  icon: const Icon(Icons.folder_open),
                                  onPressed: () {
                                    if (transfer.path != null) {
                                      OpenFilex.open(transfer.path!);
                                    }
                                  },
                                ),
                              if (isActive)
                                IconButton(
                                  icon: const Icon(Icons.cancel),
                                  onPressed: () {
                                    _connection.cancelTransfer();
                                    setState(() {
                                      transfer.cancelled = true;
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

}
