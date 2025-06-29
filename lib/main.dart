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

  final List<Peer> peers = [];
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;
    _subscription = _socket!.listen(_handleEvent);
    Timer.periodic(const Duration(seconds: 2), (_) => announce());
  }

  void announce() {
    _socket?.send(utf8.encode(message), InternetAddress('255.255.255.255'),
        broadcastPort);
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
  final DiscoveryService _discovery = DiscoveryService();

  @override
  void initState() {
    super.initState();
    _discovery.start();
  }

  @override
  void dispose() {
    _discovery.dispose();
    super.dispose();
  }

  Future<void> _sendFile(Peer peer) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final socket =
        await Socket.connect(peer.address, DiscoveryService.broadcastPort);
    await socket.addStream(file.openRead());
    await socket.flush();
    await socket.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telodoy Peers')),
      body: ListView.builder(
        itemCount: _discovery.peers.length,
        itemBuilder: (context, index) {
          final peer = _discovery.peers[index];
          return ListTile(
            title: Text(peer.address.address),
            onTap: () => _sendFile(peer),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _discovery.announce,
        child: const Icon(Icons.wifi_tethering),
      ),
    );
  }
}
