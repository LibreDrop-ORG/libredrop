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

import 'package:flutter/material.dart';

class DeviceAvatars {
  static const String defaultAvatar = 'computer';

  // Available avatar options using Material Design icons
  static const Map<String, IconData> avatarIcons = {
    'computer': Icons.computer,
    'laptop': Icons.laptop,
    'phone': Icons.phone_android,
    'tablet': Icons.tablet,
    'desktop': Icons.desktop_windows,
    'gaming': Icons.sports_esports,
    'work': Icons.business_center,
    'home': Icons.home,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'flash': Icons.flash_on,
    'rocket': Icons.rocket_launch,
  };

  // Get icon for avatar key
  static IconData getIcon(String? avatarKey) {
    if (avatarKey == null || !avatarIcons.containsKey(avatarKey)) {
      return avatarIcons[defaultAvatar]!;
    }
    return avatarIcons[avatarKey]!;
  }

  // Get display name for avatar key
  static String getDisplayName(String? avatarKey) {
    if (avatarKey == null || !avatarIcons.containsKey(avatarKey)) {
      return _capitalize(defaultAvatar);
    }
    return _capitalize(avatarKey);
  }

  // Get all available avatar keys
  static List<String> getAllAvatarKeys() {
    return avatarIcons.keys.toList();
  }

  // Helper to capitalize first letter
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}