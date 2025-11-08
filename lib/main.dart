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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'webrtc_service.dart';
import 'settings_page.dart';
import 'settings_service.dart';
import 'debug.dart';
import 'constants/avatars.dart';

const int connectionPort = 5678;

class ConnectionStatusBanner extends StatefulWidget {
  final bool connected;
  final String? remoteEmoji;
  final String? remoteIp;
  final int? negotiatedChunkSize;
  final int? negotiatedBufferThreshold;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ConnectionStatusBanner({
    super.key,
    required this.connected,
    this.remoteEmoji,
    this.remoteIp,
    this.negotiatedChunkSize,
    this.negotiatedBufferThreshold,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void didUpdateWidget(ConnectionStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate changes
    if (oldWidget.connected != widget.connected ||
        oldWidget.errorMessage != widget.errorMessage) {
      _fadeController.reset();
      _slideController.reset();
      _fadeController.forward();
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Show error banner if there's an error
    if (widget.errorMessage != null) {
      return SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Connection Failed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Semantics(
                    label: 'Retry connection',
                    hint: 'Attempts to reconnect to the previously attempted device',
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onRetry!();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: 'Show troubleshooting help',
                    hint: 'Opens a dialog with connection troubleshooting tips',
                    child: TextButton(
                      onPressed: () {
                        // Show troubleshooting tips
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Troubleshooting Tips'),
                            content: const Text(
                              '🔧 Common Solutions:\n\n'
                              '• Make sure both devices are on the same WiFi network\n'
                              '• Check if the target device is running LibreDrop\n'
                              '• Look for "✅ Server started successfully" message\n'
                              '• Try refreshing the peer list\n'
                              '• Verify the IP address is correct\n'
                              '• Check firewall settings on both devices\n'
                              '• Restart both apps if connection still fails\n\n'
                              '📱 Port 5678 must be open for connections',
                            ),
                            actions: [
                              Semantics(
                                label: 'Close troubleshooting dialog',
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text('Help'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
          ),
        );
    }

    // Show connection status
    final statusText = widget.connected
        ? 'Connected to ${widget.remoteEmoji} ${widget.remoteIp}'
        : 'LibreDrop - Ready for connections';
    
    final configText = widget.negotiatedChunkSize != null
        ? ' | WebRTC: chunk ${widget.negotiatedChunkSize}, buffer ${widget.negotiatedBufferThreshold}'
        : '';

    final Color statusColor = widget.connected 
        ? theme.colorScheme.primary 
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: widget.connected 
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: widget.connected 
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.connected ? Icons.wifi : Icons.wifi_off_outlined,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (configText.isNotEmpty)
                  Text(
                    configText.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color? activeColor;

  const PulsingIcon({
    super.key,
    required this.icon,
    required this.isActive,
    this.activeColor,
  });

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticInOut,
    ));
  }

  @override
  void didUpdateWidget(PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isActive) {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.activeColor ?? Theme.of(context).primaryColor)
                        .withValues(alpha: 0.3),
                    blurRadius: _animation.value * 8,
                    spreadRadius: _animation.value * 2,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.activeColor ?? Theme.of(context).primaryColor,
              ),
            ),
          );
        },
      );
    } else {
      return Icon(widget.icon);
    }
  }
}

Future<bool> canPing(String ip) async {
  try {
    // Try to connect to the LibreDrop port directly first
    final socket = await Socket.connect(ip, connectionPort, timeout: const Duration(seconds: 1));
    socket.destroy();
    return true;
  } catch (e) {
    // If LibreDrop port fails, just return true for local network IPs
    // This prevents false negatives while still catching obvious network issues
    if (ip.startsWith('192.168.') || ip.startsWith('10.0.') || ip.startsWith('172.')) {
      return true; // Assume local network connectivity is fine
    }
    return false;
  }
}

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
            !addr.address.startsWith('169.254') &&
            !addr.address.startsWith('10.0.2.')) { // Filter out Android emulator gateway
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
            !addr.address.startsWith('169.254') &&
            !addr.address.startsWith('10.0.2.')) { // Filter out Android emulator gateway
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
  final String? customName;
  final String? customAvatar;

  Peer(this.address, this.port, {
    required this.name, 
    required this.type, 
    this.customName, 
    this.customAvatar
  });

  String get displayName => customName?.isNotEmpty == true ? customName! : name;
  String get displayAvatar => customAvatar ?? _getDefaultAvatarForType(type);

  static String _getDefaultAvatarForType(String type) {
    switch (type.toLowerCase()) {
      case 'android':
        return 'phone';
      case 'macos':
        return 'laptop';
      case 'linux':
        return 'computer';
      case 'windows':
        return 'desktop';
      default:
        return 'computer';
    }
  }
}

class DiscoveryService {
  static const int broadcastPort = 4567;
  static const String messagePrefix = 'LIBREDROP:';
  final String deviceName;
  final String deviceType;
  final String? customName;
  final String? customAvatar;

  DiscoveryService({
    this.onLog,
    this.onDiscoveryStateChanged,
    required String localIp,
    required this.deviceName,
    required this.deviceType,
    this.customName,
    this.customAvatar,
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
  final void Function(bool)? onDiscoveryStateChanged;
  final String _localIp;
  final List<String>? knownPeers;
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _announceTimer;
  Timer? _idleTimer;
  bool _isActive = false;

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
    _setDiscoveryActive(true);
    _startIdleTimer();
  }

  void _setDiscoveryActive(bool active) {
    if (_isActive != active) {
      _isActive = active;
      onDiscoveryStateChanged?.call(active);
      debugLog('Discovery state changed to: ${active ? "active" : "idle"}');
    }
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 8), () {
      _setDiscoveryActive(false);
    });
  }

  void _resetIdleTimer() {
    _setDiscoveryActive(true);
    _startIdleTimer();
  }

  void announce() {
    debugLog('Sending discovery announcement.');
    final message = <String, dynamic>{
      'prefix': messagePrefix,
      'name': deviceName,
      'type': deviceType,
    };
    
    // Add optional custom identity fields for backward compatibility
    if (customName != null && customName!.isNotEmpty) {
      message['customName'] = customName;
    }
    if (customAvatar != null && customAvatar!.isNotEmpty) {
      message['customAvatar'] = customAvatar;
    }
    
    _socket?.send(
      utf8.encode(jsonEncode(message)),
      InternetAddress('255.255.255.255'),
      broadcastPort,
    );
    _resetIdleTimer();
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
            customName: msg['customName'],
            customAvatar: msg['customAvatar'],
          );
          debugLog(
              'Received discovery message from ${peer.address.address} (Name: ${peer.name}, Type: ${peer.type})');
          if (peer.address.address != _localIp &&
              !peers.any((p) => p.address == peer.address)) {
            peers.add(peer);
            onLog?.call(
                'Discovered peer ${peer.displayName} (${peer.address.address})');
            debugLog('Added peer ${peer.address.address}');
            _resetIdleTimer(); // Reset idle timer when new peer is discovered
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
    _idleTimer?.cancel();
    _subscription?.cancel();
    _socket?.close();
  }
}

class ConnectionService {
  ConnectionService({
    this.onLog,
    this.onConnected,
    this.onDisconnected,
    this.onConnectionError,
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
  final void Function(String)? onConnectionError;
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
  String? lastAttemptedIp;

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
    // Disable WebRTC entirely to avoid compatibility issues - use TCP-only transfers
    onLog?.call('WebRTC disabled - using TCP-only transfers for all platforms');
    _webrtc = null;
    return;
    
    onLog?.call('Initializing WebRTC (initiator: $initiator)');
    _webrtc?.dispose();
    
    try {
      _webrtc = WebRTCService(
        onSignal: (type, data) {
          final msg = jsonEncode({'type': type, 'data': data});
          debugLog('Sending WebRTC signal: $type'); // Keep for console debug
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
      onLog?.call('WebRTC initialized successfully');
    } catch (e) {
      onLog?.call('WebRTC initialization failed: $e');
      // WebRTC failed, dispose and set to null so app can continue without WebRTC
      _webrtc?.dispose();
      _webrtc = null;
      // Don't rethrow - let the app continue with TCP-only file transfers
    }
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
    try {
      await setDownloadPath(downloadsPath);
      final localIp = await getLocalIp();
      if (localIp == null) {
        onLog?.call('❌ Could not determine local IP address. Server will not start.');
        debugLog('Could not determine local IP address. Server will not start.');
        return;
      }
      
      onLog?.call('🔍 Local IP detected: $localIp');
      debugLog('Starting server on local IP: $localIp');
      debugLog('Attempting to bind ServerSocket to ${InternetAddress.anyIPv4.address}:$connectionPort');
      
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, connectionPort);
      onLog?.call('✅ Server started successfully on ${_server!.address.address}:$connectionPort');
      onLog?.call('📡 Ready to accept connections from other devices');
      debugLog('ServerSocket bound and listening on ${_server!.address.address}:${_server!.port}');
      
      _server!.listen(_handleClient);
      debugLog('ServerSocket listening for clients.');
      
    } catch (e) {
      onLog?.call('❌ Failed to start server: $e');
      if (e.toString().contains('Address already in use')) {
        onLog?.call('💡 Port $connectionPort is already in use. Try restarting the app.');
      } else if (e.toString().contains('Permission denied')) {
        onLog?.call('💡 Permission denied. The app needs network access.');
      }
      debugLog('Server start failed: $e');
      rethrow;
    }
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
    lastAttemptedIp = ip;
    if (isConnected) {
      debugLog('Already connected to $remoteIp, skipping connection to $ip');
      return;
    }
    
    onLog?.call('🔄 Attempting to connect to $ip:$connectionPort...');
    
    // First, check basic network connectivity
    onLog?.call('🌐 Checking network connectivity to $ip...');
    final canReach = await canPing(ip);
    if (!canReach) {
      final errorMsg = 'Cannot reach $ip - check if devices are on same network';
      onLog?.call('❌ $errorMsg');
      onConnectionError?.call(errorMsg);
      return;
    }
    onLog?.call('✅ Network connectivity verified');
    
    for (var i = 0; i < retries; i++) {
      try {
        onLog?.call('📞 Connection attempt ${i + 1}/$retries to $ip...');
        final socket = await Socket.connect(
          ip,
          connectionPort,
          timeout: const Duration(seconds: 5), // Increased timeout
        );
        onLog?.call('✅ Connected to $ip:$connectionPort');
        _socket = socket;
        remoteIp = ip;
        onConnected?.call();
        await _initWebRTC(initiator: true);
        socket.listen(
          _onData,
          onDone: _handleDisconnect,
          onError: (e) {
            final errorMsg = 'Connection error: $e';
            onLog?.call('❌ $errorMsg');
            onConnectionError?.call(errorMsg);
            _handleDisconnect();
          },
        );
        socket.writeln('🙂');
        await socket.flush();
        return; // Success, exit the loop
      } catch (e) {
        String errorType = 'Unknown error';
        String troubleshootHint = '';
        
        if (e.toString().contains('errno 61') || e.toString().contains('Connection refused')) {
          errorType = 'Connection refused';
          troubleshootHint = 'Device not running LibreDrop or port blocked';
        } else if (e.toString().contains('errno 64') || e.toString().contains('No route to host')) {
          errorType = 'No route to host';
          troubleshootHint = 'Check if devices are on same network';
        } else if (e.toString().contains('timeout')) {
          errorType = 'Connection timeout';
          troubleshootHint = 'Device may be unreachable or behind firewall';
        }
        
        final attemptMsg = '❌ Attempt ${i + 1}: $errorType ($troubleshootHint)';
        onLog?.call(attemptMsg);
        debugLog('Connection failed: $e');
        
        if (i < retries - 1) {
          onLog?.call('⏳ Retrying in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          final finalErrorMsg = '❌ Connection failed after $retries attempts: $errorType';
          onLog?.call(finalErrorMsg);
          onLog?.call('💡 Troubleshooting: $troubleshootHint');
          onConnectionError?.call('$finalErrorMsg\n\n$troubleshootHint');
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

enum TransferStatus {
  initiating,
  active,
  paused,
  completed,
  failed,
  cancelled,
}

class _FileTransfer {
  _FileTransfer({
    required this.name,
    required this.size,
    required this.sending,
  }) : status = TransferStatus.initiating;

  final String name;
  final int size;
  final bool sending;
  String? path;
  int transferred = 0;
  TransferStatus status;
  String? errorMessage;

  double get progress => size == 0 ? 0 : transferred / size;
  int get percentage => (progress * 100).clamp(0, 100).toInt();

  bool get isActive => status == TransferStatus.active || status == TransferStatus.initiating;
  bool get isCompleted => status == TransferStatus.completed;
  bool get isFailed => status == TransferStatus.failed;
  bool get isCancelled => status == TransferStatus.cancelled;
  bool get isPaused => status == TransferStatus.paused;

  // For backward compatibility
  bool get cancelled => status == TransferStatus.cancelled;
  set cancelled(bool value) {
    if (value) {
      status = TransferStatus.cancelled;
    }
  }

  void updateStatus(TransferStatus newStatus, [String? error]) {
    status = newStatus;
    errorMessage = error;
  }
}

class _HomePageState extends State<HomePage> {
  DiscoveryService? _discovery;
  late final ConnectionService _connection;
  late final SettingsService _settings;
  bool _connected = false;
  String? _localIp;
  String? _remoteIp;
  String? _remoteEmoji;
  String? _connectionError;
  String? _downloadsPath;
  final List<_FileTransfer> _transfers = [];
  _FileTransfer? _activeReceiveTransfer;
  _FileTransfer? _activeSendTransfer;
  final List<String> _logs = [];
  int? _negotiatedChunkSize;
  int? _negotiatedBufferThreshold;
  bool _isRefreshing = false;
  bool _isDiscoveryActive = true; // Initially active when starting discovery
  

  

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _connection = ConnectionService(
      onLog: _addLog,
      onConnected: () {
        HapticFeedback.lightImpact();
        setState(() {
          _connected = true;
          _connectionError = null; // Clear error on successful connection
        });
      },
      onDisconnected: () {
        HapticFeedback.selectionClick();
        setState(() {
          _connected = false;
          _remoteEmoji = null;
          _remoteIp = null;
          _activeReceiveTransfer = null;
          _activeSendTransfer = null;
        });
      },
      onConnectionError: (error) {
        setState(() {
          _connectionError = error;
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
          _activeReceiveTransfer!.updateStatus(TransferStatus.active);
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
        HapticFeedback.mediumImpact(); // Success haptic for completed download
        setState(() {
          if (_activeReceiveTransfer != null) {
            _activeReceiveTransfer!
              ..path = f.path
              ..transferred = _activeReceiveTransfer!.size
              ..updateStatus(TransferStatus.completed);
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
          _activeSendTransfer!.updateStatus(TransferStatus.active);
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
        HapticFeedback.mediumImpact(); // Success haptic for completed upload
        setState(() {
          if (_activeSendTransfer != null) {
            _activeSendTransfer!.transferred = _activeSendTransfer!.size;
            _activeSendTransfer!.updateStatus(TransferStatus.completed);
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

      // Load custom device identity from settings
      final customDeviceName = await _settings.loadDeviceName();
      final customDeviceAvatar = await _settings.loadDeviceAvatar();

      if (Platform.isAndroid) {
        _discovery = DiscoveryService(
          onLog: _addLog,
          onDiscoveryStateChanged: (isActive) {
            setState(() {
              _isDiscoveryActive = isActive;
            });
          },
          localIp: _localIp!,
          deviceName: deviceName,
          deviceType: deviceType,
          customName: customDeviceName,
          customAvatar: customDeviceAvatar,
          knownPeers: [],
        );
      } else {
        _discovery = DiscoveryService(
          onLog: _addLog,
          onDiscoveryStateChanged: (isActive) {
            setState(() {
              _isDiscoveryActive = isActive;
            });
          },
          localIp: _localIp!,
          deviceName: deviceName,
          deviceType: deviceType,
          customName: customDeviceName,
          customAvatar: customDeviceAvatar,
        );
      }
      _discovery!.start();
      setState(() {}); // Refresh UI after discovery starts
    });
  }


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
    setState(() {
      _logs.add(msg);
    });
  }

  Widget _getTransferStatusIcon(_FileTransfer transfer) {
    IconData iconData;
    Color? iconColor;
    
    if (transfer.sending) {
      iconData = transfer.isCompleted ? Icons.upload_rounded : Icons.upload;
    } else {
      iconData = transfer.isCompleted ? Icons.download_rounded : Icons.download;
    }
    
    switch (transfer.status) {
      case TransferStatus.initiating:
        iconColor = Colors.orange;
        break;
      case TransferStatus.active:
        iconColor = Theme.of(context).primaryColor;
        break;
      case TransferStatus.completed:
        iconColor = Colors.green;
        break;
      case TransferStatus.failed:
        iconColor = Colors.red;
        iconData = transfer.sending ? Icons.upload_file : Icons.error;
        break;
      case TransferStatus.cancelled:
        iconColor = Colors.grey;
        iconData = Icons.cancel;
        break;
      case TransferStatus.paused:
        iconColor = Colors.orange;
        iconData = Icons.pause;
        break;
    }
    
    return Icon(iconData, color: iconColor);
  }

  String _getTransferStatusText(_FileTransfer transfer) {
    switch (transfer.status) {
      case TransferStatus.initiating:
        return 'Initiating...';
      case TransferStatus.active:
        return '${transfer.percentage}% - ${transfer.sending ? 'Uploading' : 'Downloading'}';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed${transfer.errorMessage != null ? ': ${transfer.errorMessage}' : ''}';
      case TransferStatus.cancelled:
        return 'Cancelled';
      case TransferStatus.paused:
        return 'Paused at ${transfer.percentage}%';
    }
  }

  Future<void> _pickAndSendFile({Peer? peer, File? fileToSend}) async {
    File? file;
    if (fileToSend != null) {
      file = fileToSend;
    } else {
      HapticFeedback.selectionClick(); // Haptic feedback for file picker action
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        file = File(result.files.single.path!);
        HapticFeedback.lightImpact(); // Success haptic for file selection
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
    HapticFeedback.selectionClick(); // Haptic feedback for refresh action
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
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const DismissIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (intent) => Navigator.of(context).canPop() 
              ? Navigator.of(context).pop()
              : null,
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) => null, // Handled by individual widgets
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_localIp ?? 'LibreDrop'),
        actions: [
          Semantics(
            label: 'Open settings',
            hint: 'Opens the settings page to configure download location and device identity',
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                HapticFeedback.selectionClick(); // Haptic feedback for settings button
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
      floatingActionButton: Semantics(
        label: 'Send file to connected device',
        hint: 'Opens file picker to select a file for sending',
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.selectionClick(); // Haptic feedback for send file button
            _pickAndSendFile();
          },
          label: const Text('Send File'),
          icon: const Icon(Icons.send),
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ConnectionStatusBanner(
      connected: _connected,
      remoteEmoji: _remoteEmoji,
      remoteIp: _remoteIp,
      negotiatedChunkSize: _negotiatedChunkSize,
      negotiatedBufferThreshold: _negotiatedBufferThreshold,
      errorMessage: _connectionError,
      onRetry: _connection.lastAttemptedIp != null 
        ? () => _connection.connect(_connection.lastAttemptedIp!) 
        : null,
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
                  Semantics(
                    label: 'Connect to IP address',
                    hint: 'Opens dialog to manually enter an IP address to connect to',
                    child: IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Connect to IP',
                      onPressed: () {
                        HapticFeedback.selectionClick(); // Haptic feedback for connect button
                        _promptAndConnect();
                      },
                    ),
                  ),
                  Semantics(
                    label: 'Refresh peer list',
                    hint: _isDiscoveryActive 
                        ? 'Currently scanning for peers on the network' 
                        : 'Tap to scan for available devices on the network',
                    child: IconButton(
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PulsingIcon(
                              icon: Icons.refresh,
                              isActive: _isDiscoveryActive,
                              activeColor: Theme.of(context).primaryColor,
                            ),
                      tooltip: _isDiscoveryActive 
                          ? 'Discovery Active - Scanning for peers...' 
                          : 'Discovery Idle - Tap to refresh',
                      onPressed: _isRefreshing ? null : _refreshPeers,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _discovery == null || _discovery!.peers.isEmpty
                  ? RefreshIndicator(
                      onRefresh: () async {
                        await _refreshPeers();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(child: Text('Scanning for peers...\nPull down to refresh')),
                          SizedBox(height: 100),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _refreshPeers();
                      },
                      child: ListView.builder(
                        itemCount: _discovery!.peers.length,
                      itemBuilder: (context, index) {
                        final peer = _discovery!.peers[index];
                        return Dismissible(
                          key: Key('peer-${peer.address.address}'),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.connect_without_contact,
                                  color: Theme.of(context).primaryColor,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Connect',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Send File',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.send_to_mobile,
                                  color: Colors.green.shade700,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            HapticFeedback.selectionClick(); // Haptic feedback for swipe actions
                            if (direction == DismissDirection.startToEnd) {
                              // Left swipe: Connect to peer
                              _connection.connect(peer.address.address);
                            } else if (direction == DismissDirection.endToStart) {
                              // Right swipe: Send file to peer
                              _pickAndSendFile(peer: peer);
                            }
                            return false; // Prevent actual dismissal
                          },
                          child: Semantics(
                            label: 'Connect to ${peer.displayName} at ${peer.address.address}',
                            hint: 'Tap to connect, swipe left to connect, swipe right to send file',
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 150),
                              scale: 1.0,
                              child: Focus(
                                child: ListTile(
                                  focusColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  hoverColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                                leading: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    AvatarConstants.getAvatarIcon(peer.displayAvatar),
                                    color: peer.customName != null ? Theme.of(context).primaryColor : null,
                                  ),
                                ),
                          title: Text(peer.displayName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(peer.address.address),
                              if (peer.customName != null) 
                                Text(
                                  'Custom: ${peer.customName}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () =>
                              _connection.connect(peer.address.address),
                          trailing: Semantics(
                            label: 'Send file to ${peer.displayName}',
                            hint: 'Opens file picker to select a file to send to this device',
                            child: IconButton(
                              icon: const Icon(Icons.send_to_mobile),
                              onPressed: () {
                                HapticFeedback.selectionClick(); // Haptic feedback for peer send button
                                _pickAndSendFile(peer: peer);
                              },
                            ),
                          ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                        final isActive = transfer == _activeReceiveTransfer ||
                            transfer == _activeSendTransfer;

                        return Semantics(
                          label: '${transfer.sending ? "Sending" : "Receiving"} ${transfer.name}',
                          value: '${transfer.percentage}% complete, ${_getTransferStatusText(transfer)}',
                          hint: transfer.isFailed ? 'Transfer failed, retry options available' : 
                                transfer.isCompleted ? 'Transfer completed successfully' :
                                'Transfer in progress',
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              elevation: isActive ? 3 : 1,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 200),
                                scale: isActive ? 1.02 : 1.0,
                                child: Focus(
                                  child: ListTile(
                                    focusColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                    hoverColor: Theme.of(context).colorScheme.surfaceContainer,
                                    leading: _getTransferStatusIcon(transfer),
                            title: Text(
                              transfer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(transfer.transferred / 1024 / 1024).toStringAsFixed(2)} / ${(transfer.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getTransferStatusText(transfer),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: transfer.isFailed 
                                        ? Colors.red 
                                        : transfer.isCompleted 
                                            ? Colors.green 
                                            : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (transfer.isActive)
                                  TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: transfer.progress,
                                    ),
                                    builder: (context, value, child) {
                                      return LinearProgressIndicator(
                                        value: value,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).primaryColor,
                                        ),
                                      );
                                    },
                                  ),
                                if (transfer.isCompleted)
                                  LinearProgressIndicator(
                                    value: 1.0,
                                    backgroundColor: Colors.grey.shade300,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (transfer.isCompleted && !transfer.sending && transfer.path != null)
                                  Semantics(
                                    label: 'Open ${transfer.name}',
                                    hint: 'Opens the transferred file in the default application',
                                    child: IconButton(
                                      icon: const Icon(Icons.folder_open),
                                      tooltip: 'Open file',
                                      onPressed: () {
                                        HapticFeedback.selectionClick(); // Haptic feedback for open file button
                                      if (transfer.path != null) {
                                        OpenFilex.open(transfer.path!);
                                      }
                                    },
                                    ),
                                  ),
                                if (transfer.isFailed)
                                  Semantics(
                                    label: 'Retry failed transfer of ${transfer.name}',
                                    hint: 'Attempts to restart the failed file transfer',
                                    child: IconButton(
                                      icon: const Icon(Icons.refresh, color: Colors.orange),
                                      tooltip: 'Retry transfer',
                                      onPressed: () {
                                        HapticFeedback.selectionClick(); // Haptic feedback for retry button
                                      // TODO: Implement retry functionality
                                      _addLog('Retry not implemented yet');
                                    },
                                    ),
                                  ),
                                if (isActive)
                                  Semantics(
                                    label: 'Cancel active transfer of ${transfer.name}',
                                    hint: 'Stops the ongoing file transfer permanently',
                                    child: IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red),
                                      tooltip: 'Cancel transfer',
                                      onPressed: () {
                                        HapticFeedback.heavyImpact(); // Strong haptic for cancel action
                                      _connection.cancelTransfer();
                                      setState(() {
                                        transfer.updateStatus(TransferStatus.cancelled);
                                      });
                                    },
                                    ),
                                  ),
                              ],
                            ),
                                  ),
                              ),
                            ),
                          ),
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
