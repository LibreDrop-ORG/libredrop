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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.currentPath});

  final String? currentPath;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _path = widget.currentPath;
  }

  Future<void> _choosePath() async {
    HapticFeedback.selectionClick(); // Haptic feedback for directory picker
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      setState(() => _path = dir);
      HapticFeedback.lightImpact(); // Success haptic for directory selection
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _path == null
                  ? 'Using default downloads directory.'
                  : 'Save files to: $_path',
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _choosePath,
              child: const Text('Choose directory'),
            ),
            const Spacer(),
            // Version information
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LibreDrop v0.3.0-beta.1',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact(); // Haptic feedback for done button
                Navigator.of(context).pop(_path);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
