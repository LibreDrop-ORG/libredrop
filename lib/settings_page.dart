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
import 'dart:io';

import 'constants/avatars.dart';
import 'settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.currentPath});

  final String? currentPath;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _path;
  String? _deviceName;
  String? _deviceAvatar;
  final _deviceNameController = TextEditingController();
  final _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _path = widget.currentPath;
    _loadDeviceIdentity();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceIdentity() async {
    final name = await _settingsService.loadDeviceName();
    final avatar = await _settingsService.loadDeviceAvatar();
    
    setState(() {
      _deviceName = name ?? Platform.localHostname;
      _deviceAvatar = avatar ?? DeviceAvatars.defaultAvatar;
      _deviceNameController.text = name ?? '';
    });
  }

  Future<void> _choosePath() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      setState(() => _path = dir);
    }
  }

  Future<void> _saveDeviceIdentity() async {
    final name = _deviceNameController.text.trim();
    if (name.isNotEmpty) {
      await _settingsService.saveDeviceName(name);
    } else {
      await _settingsService.saveDeviceName(null);
    }
    
    if (_deviceAvatar != DeviceAvatars.defaultAvatar) {
      await _settingsService.saveDeviceAvatar(_deviceAvatar);
    } else {
      await _settingsService.saveDeviceAvatar(null);
    }
  }

  String? _validateDeviceName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    final trimmed = value.trim();
    if (trimmed.length > 30) {
      return 'Device name must be 30 characters or less';
    }
    
    if (RegExp(r'[<>:"/\\|?*]').hasMatch(trimmed)) {
      return 'Device name contains invalid characters';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Identity Section
              Text(
                'Device Identity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deviceNameController,
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  hintText: _deviceName ?? Platform.localHostname,
                  border: const OutlineInputBorder(),
                  helperText: 'How other devices see your device (optional)',
                ),
                validator: _validateDeviceName,
                maxLength: 30,
              ),
              const SizedBox(height: 16),
              Text(
                'Avatar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: DeviceAvatars.getAllAvatarKeys().length,
                  itemBuilder: (context, index) {
                    final avatarKey = DeviceAvatars.getAllAvatarKeys()[index];
                    final isSelected = _deviceAvatar == avatarKey;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _deviceAvatar = avatarKey;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).primaryColor 
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected 
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                              : null,
                        ),
                        child: Icon(
                          DeviceAvatars.getIcon(avatarKey),
                          color: isSelected 
                              ? Theme.of(context).primaryColor 
                              : Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              // Download Directory Section
              Text(
                'Download Directory',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
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
                onPressed: () async {
                  final form = Form.of(context);
                  final navigator = Navigator.of(context);
                  if (form.validate()) {
                    await _saveDeviceIdentity();
                    if (mounted) {
                      navigator.pop(_path);
                    }
                  }
                },
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
