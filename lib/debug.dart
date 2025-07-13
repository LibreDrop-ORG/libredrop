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
// You should have received a copy of the GNU GPL
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

library opendrop_debug;

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

FileLogger? _fileLogger;

class FileLogger {
  FileLogger(this._logFile);

  final File _logFile;
  IOSink? _sink;

  Future<void> init() async {
    _sink = _logFile.openWrite(mode: FileMode.append);
  }

  void log(String message) {
    _sink?.writeln('${DateTime.now()}: $message');
  }

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}

void debugLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[DEBUG] $message');
    _fileLogger?.log(message); // Log to file if logger is initialized
  }
}

// Function to initialize the file logger
Future<void> initializeFileLogger(String instanceName, {String? logDirectoryPath}) async {
  if (kDebugMode) {
    // ignore: avoid_print
    print('[DEBUG] Attempting to initialize file logger for instance: $instanceName');
    // ignore: avoid_print
    print('[DEBUG] Provided logDirectoryPath: $logDirectoryPath');
    try {
      Directory baseDir;
      if (logDirectoryPath != null && logDirectoryPath.isNotEmpty) {
        baseDir = Directory(logDirectoryPath);
        // ignore: avoid_print
        print('[DEBUG] Using provided logDirectoryPath as baseDir: ${baseDir.path}');
      } else {
        baseDir = await getApplicationSupportDirectory();
        // ignore: avoid_print
        print('[DEBUG] Using getApplicationSupportDirectory as baseDir: ${baseDir.path}');
      }
      final logDir = Directory('${baseDir.path}/logs');
      // ignore: avoid_print
      print('[DEBUG] Log directory path: ${logDir.path}');
      if (!await logDir.exists()) {
        // ignore: avoid_print
        print('[DEBUG] Log directory does not exist, creating: ${logDir.path}');
        await logDir.create(recursive: true);
        // ignore: avoid_print
        print('[DEBUG] Log directory created.');
      }
      final logFile = File('${logDir.path}/opendrop_debug_${instanceName}_${DateTime.now().millisecondsSinceEpoch}.log');
      // ignore: avoid_print
      print('[DEBUG] Log file path: ${logFile.path}');
      _fileLogger = FileLogger(logFile);
      await _fileLogger?.init();
      debugLog('File logging initialized to: ${logFile.path}');
    } catch (e) {
      // ignore: avoid_print
      print('Error initializing file logger: $e');
    }
  }
}

// Function to dispose the file logger
Future<void> disposeFileLogger() async {
  await _fileLogger?.dispose();
  _fileLogger = null;
}