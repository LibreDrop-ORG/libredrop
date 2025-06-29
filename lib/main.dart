import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

const int connectionPort = 5678;

Future<String?> getLocalIp() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
        return addr.address;
      }
    }
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

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;
    _subscription = _socket!.listen(_handleEvent);
    onLog?.call('Discovery started on port ${_socket!.port}');
    Timer.periodic(const Duration(seconds: 2), (_) => announce());
  }

  void announce() {
    _socket?.send(
      utf8.encode(message),
      InternetAddress('255.255.255.255'),
      broadcastPort,
    );
    onLog?.call('Announced to network');
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
    _subscription?.cancel();
    _socket?.close();
  }
}

class ConnectionService {
  ConnectionService({this.onLog});

  final void Function(String)? onLog;
  ServerSocket? _server;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, connectionPort);
    onLog?.call('Listening on ${_server!.address.address}:$connectionPort');
    _server!.listen(_handleClient);
  }

  void _handleClient(Socket client) {
    onLog?.call('Client connected from ${client.remoteAddress.address}');
    client.writeln('👋');
    client.flush();
    client.listen(
      (data) => onLog?.call(
        'Received: ${utf8.decode(data).trim()} from ${client.remoteAddress.address}',
      ),
      onDone: client.destroy,
    );
  }

  Future<void> connect(String ip) async {
    final socket = await Socket.connect(ip, connectionPort);
    socket.listen(
      (data) => onLog?.call('Received: ${utf8.decode(data).trim()} from $ip'),
      onDone: socket.destroy,
    );
    socket.writeln('🙂');
    await socket.flush();
  }

  void dispose() {
    _server?.close();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DiscoveryService _discovery;
  late final ConnectionService _connection;
  String? _localIp;
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
    _connection = ConnectionService(onLog: _addLog);
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
    final socket = await Socket.connect(
      peer.address,
      DiscoveryService.broadcastPort,
    );
    await socket.addStream(file.openRead());
    await socket.flush();
    await socket.close();
  }

  Future<void> _promptAndConnect() async {
    final controller = TextEditingController();
    final ip = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_localIp != null) Text("Your IP: $_localIp"),
                const SizedBox(height: 4),
                Text("Peers found: ${_discovery.peers.length}"),
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
                children: _logs
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
