import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'webrtc_service.dart';
import 'settings_page.dart';
import 'settings_service.dart';

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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenDrop',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class Peer {
  final InternetAddress address;
  final int port;

  Peer(this.address, this.port);
}

class DiscoveryService {
  static const int broadcastPort = 4567;
  static const String message = 'OPENDROP';

  DiscoveryService({this.onLog});

  final List<Peer> peers = [];
  final void Function(String)? onLog;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _announceTimer;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;
    _subscription = _socket!.listen(_handleEvent);
    onLog?.call('Discovery started on port ${_socket!.port}');
    _announceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => announce(),
    );
  }

  void announce() {
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
      final msg = utf8.decode(dg.data);
      if (msg == message) {
        final peer = Peer(dg.address, dg.port);
        if (!peers.any((p) => p.address == peer.address)) {
          peers.add(peer);
          onLog?.call('Discovered peer ${peer.address.address}');
        }
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

  void _initWebRTC({required bool initiator}) {
    _webrtc?.dispose();
    _webrtc = WebRTCService(
      onSignal: (type, data) {
        final msg = jsonEncode({'type': type, 'data': data});
        _socket?.writeln('WEBRTC:$msg');
        _socket?.flush();
      },
      onConnected: () => onLog?.call('WebRTC connected'),
      onDisconnected: () => onLog?.call('WebRTC disconnected'),
      onFileStarted: onFileStarted,
      onFileProgress: onFileProgress,
      onFileReceived: onFileReceived,
      onSendStarted: onSendStarted,
      onSendProgress: onSendProgress,
      onSendComplete: onSendComplete,
    );
    unawaited(_webrtc!.createPeer(initiator: initiator));
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
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, connectionPort);
    onLog?.call('Listening on ${_server!.address.address}:$connectionPort');
    _server!.listen(_handleClient);
  }

  void _handleClient(Socket client) {
    onLog?.call('Client connected from ${client.remoteAddress.address}');
    _socket = client;
    remoteIp = client.remoteAddress.address;
    onConnected?.call();
    _initWebRTC(initiator: false);
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

  Future<void> connect(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        connectionPort,
        timeout: const Duration(seconds: 5),
      );
      onLog?.call('Connected to $ip:$connectionPort');
      _socket = socket;
      remoteIp = ip;
      onConnected?.call();
      _initWebRTC(initiator: true);
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
    } catch (e) {
      onLog?.call('Failed to connect to $ip:$connectionPort -> $e');
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
        await for (final chunk in file.openRead()) {
          if (!_sendingFile) break;
          _socket!.add(chunk);
          _bytesSent += chunk.length;
          onSendProgress?.call(_bytesSent, _totalToSend);
        }
        await _socket!.flush();
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
      if (!_gotGreeting) {
        remoteEmoji = line.trim();
        _gotGreeting = true;
        onGreeting?.call(remoteEmoji!);
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
      } else if (line.startsWith('WEBRTC:')) {
        final msg = jsonDecode(line.substring(7));
        final type = msg['type'] as String;
        final data = Map<String, dynamic>.from(msg['data'] as Map);
        await _webrtc?.handleSignal(type, data);
      } else if (line.trim() == 'ACK' && _ackCompleter != null) {
        _ackCompleter?.complete();
        _ackCompleter = null;
      } else if (line.trim() == 'CANCEL') {
        _sendingFile = false;
        _receivingFile = false;
        _ackCompleter?.completeError('cancelled');
      } else {
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
  late final DiscoveryService _discovery;
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

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
    });
  }

  @override
  void initState() {
    super.initState();
    _discovery = DiscoveryService(onLog: _addLog);
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
    );
    _discovery.start();
    _connection.start();
    _settings.loadDownloadPath().then((p) async {
      await _connection.setDownloadPath(p);
      setState(() {
        _downloadsPath = p;
      });
    });
    getLocalIp().then((ip) {
      setState(() {
        _localIp = ip;
      });
    });
  }

  @override
  void dispose() {
    _discovery.dispose();
    _connection.dispose();
    super.dispose();
  }

  Future<void> _sendFile(Peer peer) async {
    _addLog('Sending file to ${peer.address.address}');
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    await _connection.connect(peer.address.address);
    await _connection.sendFile(file);
  }

  Future<void> _promptAndConnect() async {
    final controller = TextEditingController();
    final ip = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Connect to IP'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter IP address'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Connect'),
              ),
            ],
          ),
    );
    if (ip != null && ip.isNotEmpty) {
      _addLog('Connecting to $ip');
      await _connection.connect(ip);
    }
  }

  Future<void> _sendFileToConnection() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    await _connection.sendFile(file);
  }

  Future<void> _openSettings() async {
    final path = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(currentPath: _downloadsPath),
      ),
    );
    if (path != null) {
      await _settings.saveDownloadPath(path);
      await _connection.setDownloadPath(path);
      setState(() => _downloadsPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenDrop Peers'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'connect':
                  _promptAndConnect();
                  break;
                case 'send':
                  if (_connected) _sendFileToConnection();
                  break;
                case 'settings':
                  _openSettings();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'connect',
                    child: Text('Conectar a IP'),
                  ),
                  PopupMenuItem(
                    value: 'send',
                    enabled: _connected,
                    child: const Text('Enviar archivo'),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Settings'),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_localIp != null) Text('Your IP: $_localIp'),
                const SizedBox(height: 4),
                if (_remoteIp != null && _remoteEmoji != null)
                  Text('Connected to $_remoteIp $_remoteEmoji'),
                ..._transfers.map(
                  (t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: t.progress,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${t.percentage}%'),
                            ],
                          ),
                        ),
                        if (t.progress < 1 && !t.cancelled)
                          IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              _connection.cancelTransfer();
                              setState(() {
                                t.cancelled = true;
                                if (t.sending) {
                                  _activeSendTransfer = null;
                                } else {
                                  _activeReceiveTransfer = null;
                                }
                              });
                            },
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap:
                              t.path != null
                                  ? () => OpenFilex.open(t.path!)
                                  : null,
                          child: Text(
                            t.name,
                            style: TextStyle(
                              color: t.path != null ? Colors.blue : null,
                              decoration:
                                  t.path != null
                                      ? TextDecoration.underline
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text('Peers found: ${_discovery.peers.length}'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _discovery.peers.length,
              itemBuilder: (context, index) {
                final peer = _discovery.peers[index];
                return ListTile(
                  title: Text(peer.address.address),
                  onTap: () => _sendFile(peer),
                );
              },
            ),
          ),
          if (_logs.isNotEmpty)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              height: 120,
              child: ListView(
                children:
                    _logs
                        .map(
                          (l) => Text(
                            l,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _discovery.announce,
        child: const Icon(Icons.wifi_tethering),
      ),
    );
  }
}
