import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
      title: 'Telodoy',
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
  static const String message = 'TELODOY';

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
  });

  final void Function(String)? onLog;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final void Function(String)? onGreeting;
  final void Function(String, int)? onFileStarted;
  final void Function(int, int)? onFileProgress;
  final void Function(File)? onFileReceived;
  ServerSocket? _server;
  Socket? _socket;

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

  Future<void> start() async {
    _downloads = await getDownloadsDirectory();
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, connectionPort);
    onLog?.call('Listening on ${_server!.address.address}:$connectionPort');
    _server!.listen(_handleClient);
  }

  void _handleClient(Socket client) {
    onLog?.call('Client connected from ${client.remoteAddress.address}');
    _socket = client;
    remoteIp = client.remoteAddress.address;
    onConnected?.call();
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
    if (_socket == null) {
      onLog?.call('No active connection to send file');
      return;
    }
    try {
      onLog?.call('Sending file ${file.path}');
      final length = await file.length();
      final name = file.uri.pathSegments.last;
      _socket!.write('FILE:$name:$length\n');
      await _socket!.addStream(file.openRead());
      await _socket!.flush();
    } catch (e) {
      onLog?.call('Failed to send file: $e');
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
    onDisconnected?.call();
    onLog?.call('Connection closed');
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
      } else {
        onLog?.call('Received: $line');
      }
    }
  }

  void dispose() {
    _server?.close();
    _fileSink?.close();
    _socket?.destroy();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _FileTransfer {
  _FileTransfer({required this.name, required this.size});

  final String name;
  final int size;
  String? path;
  int received = 0;

  double get progress => size == 0 ? 0 : received / size;
}

class _HomePageState extends State<HomePage> {
  late final DiscoveryService _discovery;
  late final ConnectionService _connection;
  bool _connected = false;
  String? _localIp;
  String? _remoteIp;
  String? _remoteEmoji;
  final List<_FileTransfer> _transfers = [];
  _FileTransfer? _activeTransfer;
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
    _connection = ConnectionService(
      onLog: _addLog,
      onConnected: () => setState(() => _connected = true),
      onDisconnected: () {
        setState(() {
          _connected = false;
          _remoteEmoji = null;
          _remoteIp = null;
          _activeTransfer = null;
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
          _activeTransfer = _FileTransfer(name: name, size: size);
          _transfers.add(_activeTransfer!);
        });
      },
      onFileProgress: (r, t) {
        setState(() {
          if (_activeTransfer != null) {
            _activeTransfer!.received = r;
          }
        });
      },
      onFileReceived: (f) {
        setState(() {
          if (_activeTransfer != null) {
            _activeTransfer!
              ..path = f.path
              ..received = _activeTransfer!.size;
            _activeTransfer = null;
          }
        });
        _addLog('Saved file ${f.path}');
      },
    );
    _discovery.start();
    _connection.start();
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
    final socket = await Socket.connect(peer.address, connectionPort);
    final length = await file.length();
    final name = file.uri.pathSegments.last;
    socket.write('FILE:$name:$length\n');
    await socket.addStream(file.openRead());
    await socket.flush();
    await socket.close();
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

  void _showFileInfo(_FileTransfer transfer) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(transfer.name),
            content: Text(
              'Size: ${transfer.size} bytes\nSaved at: ${transfer.path ?? 'Saving...'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telodoy Peers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: _promptAndConnect,
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _connected ? _sendFileToConnection : null,
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
                    child: GestureDetector(
                      onTap: () => _showFileInfo(t),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(value: t.progress),
                          ),
                          const SizedBox(width: 8),
                          Text(t.name),
                        ],
                      ),
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
