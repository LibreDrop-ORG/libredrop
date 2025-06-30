import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      setState(() => _path = dir);
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
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_path),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
