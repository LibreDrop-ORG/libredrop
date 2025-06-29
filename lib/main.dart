import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DiscoveryService _discovery;
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
    _discovery.start();
  }

  @override
  void dispose() {
    _discovery.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telodoy Peers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Peers found: ${_discovery.peers.length}'),
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
