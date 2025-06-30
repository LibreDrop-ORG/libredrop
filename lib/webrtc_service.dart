import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

typedef SignalCallback = void Function(String type, Map<String, dynamic> data);

typedef ProgressCallback = void Function(int transferred, int total);

typedef FileCallback = void Function(String name, int size);

class WebRTCService {
  WebRTCService({
    required this.onSignal,
    this.onConnected,
    this.onDisconnected,
    this.onFileStarted,
    this.onFileProgress,
    this.onFileReceived,
    this.onSendStarted,
    this.onSendProgress,
    this.onSendComplete,
  });

  final SignalCallback onSignal;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final FileCallback? onFileStarted;
  final ProgressCallback? onFileProgress;
  final void Function(File)? onFileReceived;
  final FileCallback? onSendStarted;
  final ProgressCallback? onSendProgress;
  final VoidCallback? onSendComplete;

  RTCPeerConnection? _peer;
  RTCDataChannel? _channel;

  IOSink? _fileSink;
  late String _currentFileName;
  int _currentFileSize = 0;
  int _bytesReceived = 0;

  bool _sendingFile = false;
  int _bytesSent = 0;
  int _totalToSend = 0;
  Completer<void>? _ackCompleter;

  Future<void> createPeer({required bool initiator}) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _peer = await createPeerConnection(config);
    _peer!.onIceCandidate = (candidate) {
      onSignal('ice', candidate.toMap());
    };
    _peer!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onConnected?.call();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onDisconnected?.call();
      }
    };

    if (initiator) {
      _channel = await _peer!.createDataChannel('file', RTCDataChannelInit());
      _setupChannel();
      final offer = await _peer!.createOffer();
      await _peer!.setLocalDescription(offer);
      final desc = await _peer!.getLocalDescription();
      if (desc != null) onSignal('sdp', desc.toMap());
    } else {
      _peer!.onDataChannel = (channel) {
        _channel = channel;
        _setupChannel();
      };
    }
  }

  void _setupChannel() {
    if (_channel == null) return;
    _channel!.onMessage = (message) {
      if (message.isBinary) {
        _handleBinary(message.binary);
      } else {
        _handleText(message.text);
      }
    };
    _channel!.onDataChannelState = (state) {};
  }

  Future<void> handleSignal(String type, Map<String, dynamic> data) async {
    switch (type) {
      case 'sdp':
        final desc = RTCSessionDescription(
          data['sdp'] as String,
          data['type'] as String,
        );
        await _peer!.setRemoteDescription(desc);
        if (desc.type == 'offer') {
          final answer = await _peer!.createAnswer();
          await _peer!.setLocalDescription(answer);
          final local = await _peer!.getLocalDescription();
          if (local != null) onSignal('sdp', local.toMap());
        }
        break;
      case 'ice':
        if (data['candidate'] != null) {
          final cand = RTCIceCandidate(
            data['candidate'] as String,
            data['sdpMid'] as String?,
            data['sdpMLineIndex'] as int?,
          );
          await _peer!.addCandidate(cand);
        }
        break;
    }
  }

  Future<void> _handleText(String text) async {
    if (text.startsWith('FILE:')) {
      final parts = text.split(':');
      if (parts.length == 3) {
        _currentFileName = parts[1];
        _currentFileSize = int.tryParse(parts[2]) ?? 0;
        final dir = await getDownloadsDirectory();
        final file = File('${dir!.path}/$_currentFileName');
        _fileSink = file.openWrite();
        _bytesReceived = 0;
        onFileStarted?.call(_currentFileName, _currentFileSize);
      }
    } else if (text.trim() == 'ACK') {
      _sendingFile = false;
      _ackCompleter?.complete();
      _ackCompleter = null;
      onSendComplete?.call();
    }
  }

  Future<void> _handleBinary(Uint8List data) async {
    if (_fileSink == null) return;
    _fileSink!.add(data);
    _bytesReceived += data.length;
    onFileProgress?.call(_bytesReceived, _currentFileSize);
    if (_bytesReceived >= _currentFileSize) {
      await _fileSink!.flush();
      await _fileSink!.close();
      final dir = await getDownloadsDirectory();
      final file = File('${dir!.path}/$_currentFileName');
      onFileReceived?.call(file);
      _fileSink = null;
      _bytesReceived = 0;
      _channel?.send(RTCDataChannelMessage('ACK'));
    }
  }

  Future<void> sendFile(File file) async {
    if (_channel == null) return;
    while (_channel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _totalToSend = await file.length();
    final name = file.uri.pathSegments.last;
    while (true) {
      _sendingFile = true;
      _bytesSent = 0;
      onSendStarted?.call(name, _totalToSend);
      _ackCompleter = Completer<void>();

      _channel!.send(RTCDataChannelMessage('FILE:$name:$_totalToSend'));
      await for (final chunk in file.openRead()) {
        if (!_sendingFile) break;
        _channel!
            .send(RTCDataChannelMessage.fromBinary(Uint8List.fromList(chunk)));
        _bytesSent += chunk.length;
        onSendProgress?.call(_bytesSent, _totalToSend);
      }

      try {
        await _ackCompleter!.future.timeout(const Duration(seconds: 5));
        break;
      } on TimeoutException {
        // retry
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  void dispose() {
    _fileSink?.close();
    _channel?.close();
    _peer?.close();
  }
}
