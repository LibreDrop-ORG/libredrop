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

import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _downloadKey = 'download_path';
  static const _deviceNameKey = 'device_name';
  static const _deviceAvatarKey = 'device_avatar';

  Future<String?> loadDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_downloadKey);
  }

  Future<void> saveDownloadPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_downloadKey);
    } else {
      await prefs.setString(_downloadKey, path);
    }
  }

  Future<String?> loadDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceNameKey);
  }

  Future<void> saveDeviceName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.isEmpty) {
      await prefs.remove(_deviceNameKey);
    } else {
      await prefs.setString(_deviceNameKey, name);
    }
  }

  Future<String?> loadDeviceAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceAvatarKey);
  }

  Future<void> saveDeviceAvatar(String? avatar) async {
    final prefs = await SharedPreferences.getInstance();
    if (avatar == null || avatar.isEmpty) {
      await prefs.remove(_deviceAvatarKey);
    } else {
      await prefs.setString(_deviceAvatarKey, avatar);
    }
  }
}
