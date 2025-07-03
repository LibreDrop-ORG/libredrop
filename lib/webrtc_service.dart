// OpenDrop - Local network file sharing app
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
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'debug.dart';

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

  final List<RTCIceCandidate> _pendingCandidates = [];

  IOSink? _fileSink;
  late String _currentFileName;
  int _currentFileSize = 0;
  int _bytesReceived = 0;

  bool _sendingFile = false;
  int _bytesSent = 0;
  int _totalToSend = 0;
  Completer<void>? _ackCompleter;


  Future<void> createPeer({required bool initiator}) async {
    debugLog('Creating peer, initiator: $initiator');
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _peer = await createPeerConnection(config);
    debugLog('Peer connection created');
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
    debugLog('Setting up data channel');
    _channel!.bufferedAmountLowThreshold = 1024 * 1024;
    _channel!.onMessage = (message) {
      if (message.isBinary) {
        _handleBinary(message.binary);
      } else {
        _handleText(message.text);
      }
    };
    _channel!.onDataChannelState = (state) {
      debugLog('Data channel state: $state');
    };
  }

  Future<void> handleSignal(String type, Map<String, dynamic> data) async {
    debugLog('Handling signal: $type');
    if (_peer == null) {
      debugLog('Peer not ready when signal "$type" received');
      return;
    }
    switch (type) {
      case 'sdp':
        final desc = RTCSessionDescription(
          data['sdp'] as String,
          data['type'] as String,
        );
        if (desc.type == 'answer') {
          RTCSessionDescription? current;
          try {
            current = await _peer!.getRemoteDescription();
          } catch (_) {
            current = null;
          }
          if (current != null) return;
        }
        await _peer!.setRemoteDescription(desc);
        debugLog('Set remote description type: ${desc.type}');
        for (final c in _pendingCandidates) {
          await _peer!.addCandidate(c);
        }
        _pendingCandidates.clear();
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
          RTCSessionDescription? current;
          try {
            current = await _peer!.getRemoteDescription();
          } catch (_) {
            current = null;
          }
          if (current == null) {
            _pendingCandidates.add(cand);
            debugLog('Queued ICE candidate');
          } else {
            await _peer!.addCandidate(cand);
            debugLog('Added ICE candidate');
          }
        }
        break;
    }
  }

  Future<void> _handleText(String text) async {
    debugLog('Received text message: $text');
    if (text.startsWith('FILE:')) {
      final parts = text.split(':');
      if (parts.length == 3) {
        _currentFileName = parts[1];
        _currentFileSize = int.tryParse(parts[2]) ?? 0;
        final dir = await getDownloadsDirectory();
        final file = File('${dir!.path}/$_currentFileName');
        _fileSink = file.openWrite();
        _bytesReceived = 0;
        debugLog('Start receiving $_currentFileName of size $_currentFileSize');
        onFileStarted?.call(_currentFileName, _currentFileSize);
      }
    } else if (text.trim() == 'ACK') {
      _sendingFile = false;
      _ackCompleter?.complete();
      _ackCompleter = null;
      debugLog('Received ACK');
      onSendComplete?.call();
    }
  }

  Future<void> _handleBinary(Uint8List data) async {
    if (_fileSink == null) return;
    debugLog('Received ${data.length} bytes');
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
    debugLog('Preparing to send file ${file.path}');
    while (_channel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _totalToSend = await file.length();
    final name = file.uri.pathSegments.last;
    while (true) {
      debugLog('Sending file iteration');
      _sendingFile = true;
      _bytesSent = 0;
      onSendStarted?.call(name, _totalToSend);
      _ackCompleter = Completer<void>();

      _channel!.send(RTCDataChannelMessage('FILE:$name:$_totalToSend'));
      await for (final chunk in file.openRead()) {
        if (!_sendingFile) break;
        // Wait for the buffered amount to drop to avoid closing the channel
        await _waitForBuffer();
        _channel!
            .send(RTCDataChannelMessage.fromBinary(Uint8List.fromList(chunk)));
        _bytesSent += chunk.length;
        onSendProgress?.call(_bytesSent, _totalToSend);
        debugLog('Sent ${chunk.length} bytes');
      }

      try {
        await _ackCompleter!.future.timeout(const Duration(seconds: 5));
        debugLog('Send completed');
        break;
      } on TimeoutException {
        // retry
        debugLog('ACK timeout, retrying');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _waitForBuffer() async {
    while (_channel != null &&
        _channel!.bufferedAmount >= _channel!.bufferedAmountLowThreshold) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void dispose() {
    _fileSink?.close();
    _channel?.close();
    _peer?.close();
  }
}
