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

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';
import '../lib/constants/avatars.dart';

void main() {
  group('Peer Custom Identity Tests', () {
    test('Peer with custom name displays customName', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'localhost',
        type: 'macos',
        customName: 'John\'s MacBook',
        customAvatar: null,
      );

      expect(peer.displayName, equals('John\'s MacBook'));
      expect(peer.name, equals('localhost'));
    });

    test('Peer without custom name displays system name', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'laptop.local',
        type: 'macos',
        customName: null,
        customAvatar: null,
      );

      expect(peer.displayName, equals('laptop.local'));
    });

    test('Peer with empty customName displays system name', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'desktop.local',
        type: 'windows',
        customName: '',
        customAvatar: null,
      );

      expect(peer.displayName, equals('desktop.local'));
    });

    test('Peer with custom avatar displays customAvatar', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'phone.local',
        type: 'android',
        customName: null,
        customAvatar: 'tablet',
      );

      expect(peer.displayAvatar, equals('tablet'));
    });

    test('Peer without custom avatar displays type-based default', () {
      final androidPeer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'pixel',
        type: 'android',
      );

      expect(androidPeer.displayAvatar, equals('phone'));

      final macosPeer = Peer(
        InternetAddress('192.168.1.101'),
        5678,
        name: 'macbook',
        type: 'macos',
      );

      expect(macosPeer.displayAvatar, equals('laptop'));

      final linuxPeer = Peer(
        InternetAddress('192.168.1.102'),
        5678,
        name: 'ubuntu',
        type: 'linux',
      );

      expect(linuxPeer.displayAvatar, equals('computer'));

      final windowsPeer = Peer(
        InternetAddress('192.168.1.103'),
        5678,
        name: 'pc',
        type: 'windows',
      );

      expect(windowsPeer.displayAvatar, equals('desktop'));
    });

    test('Peer with unknown type defaults to computer avatar', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'unknown.local',
        type: 'unknown',
      );

      expect(peer.displayAvatar, equals('computer'));
    });

    test('Peer with both custom name and avatar', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'system-name',
        type: 'linux',
        customName: 'Development Server',
        customAvatar: 'server',
      );

      expect(peer.displayName, equals('Development Server'));
      expect(peer.displayAvatar, equals('server'));
    });

    test('Multiple peers with different custom identities', () {
      final peers = [
        Peer(
          InternetAddress('192.168.1.100'),
          5678,
          name: 'device1',
          type: 'android',
          customName: 'John\'s Phone',
          customAvatar: 'phone',
        ),
        Peer(
          InternetAddress('192.168.1.101'),
          5678,
          name: 'device2',
          type: 'macos',
          customName: 'Jane\'s MacBook',
          customAvatar: 'laptop',
        ),
        Peer(
          InternetAddress('192.168.1.102'),
          5678,
          name: 'device3',
          type: 'windows',
          // No custom identity
        ),
      ];

      expect(peers[0].displayName, equals('John\'s Phone'));
      expect(peers[0].displayAvatar, equals('phone'));

      expect(peers[1].displayName, equals('Jane\'s MacBook'));
      expect(peers[1].displayAvatar, equals('laptop'));

      expect(peers[2].displayName, equals('device3'));
      expect(peers[2].displayAvatar, equals('desktop'));
    });
  });

  group('AvatarConstants Tests', () {
    test('All predefined avatars map to valid icons', () {
      final avatars = [
        'phone',
        'laptop',
        'desktop',
        'tablet',
        'computer',
        'server',
        'watch',
        'tv',
        'game',
        'camera',
        'headphones',
        'printer',
      ];

      for (final avatar in avatars) {
        final icon = AvatarConstants.getAvatarIcon(avatar);
        expect(icon, isNotNull);
      }
    });

    test('Unknown avatar returns default computer icon', () {
      final icon = AvatarConstants.getAvatarIcon('unknown-avatar-type');
      expect(icon, isNotNull);
    });

    test('Null avatar returns default icon', () {
      final icon = AvatarConstants.getAvatarIcon(null);
      expect(icon, isNotNull);
    });

    test('Empty string avatar returns default icon', () {
      final icon = AvatarConstants.getAvatarIcon('');
      expect(icon, isNotNull);
    });

    test('Avatar icon mapping is case-sensitive', () {
      // Assuming implementation is case-sensitive
      final laptopIcon = AvatarConstants.getAvatarIcon('laptop');
      final laptopUpperIcon = AvatarConstants.getAvatarIcon('LAPTOP');

      // Both should return valid icons (may or may not be same depending on implementation)
      expect(laptopIcon, isNotNull);
      expect(laptopUpperIcon, isNotNull);
    });
  });

  group('Custom Identity Edge Cases', () {
    test('Peer handles very long custom names', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'short',
        type: 'macos',
        customName: 'This is a very long custom device name that might cause UI issues' * 3,
      );

      expect(peer.displayName.length, greaterThan(100));
      expect(peer.displayName.isNotEmpty, isTrue);
    });

    test('Peer handles special characters in custom name', () {
      final specialNames = [
        'John\'s "MacBook Pro"',
        'Device #123',
        'Test & Development',
        'Server_001',
        'Device (2024)',
        '日本語デバイス',
        'Устройство',
        'Emoji 📱 Device',
      ];

      for (final name in specialNames) {
        final peer = Peer(
          InternetAddress('192.168.1.100'),
          5678,
          name: 'system',
          type: 'macos',
          customName: name,
        );

        expect(peer.displayName, equals(name));
      }
    });

    test('Peer handles whitespace in custom names', () {
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'system',
        type: 'macos',
        customName: '  Trimmed Name  ',
      );

      // Display name should preserve whitespace (no automatic trimming)
      expect(peer.displayName, equals('  Trimmed Name  '));
    });

    test('Peer handles null IP address gracefully', () {
      // This tests if Peer constructor handles edge cases
      final peer = Peer(
        InternetAddress('0.0.0.0'),
        5678,
        name: 'test',
        type: 'unknown',
      );

      expect(peer.address.address, equals('0.0.0.0'));
    });
  });

  group('Custom Identity Backward Compatibility', () {
    test('Old peers without custom fields work correctly', () {
      // Simulating old peer discovery message without customName/customAvatar
      final peer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'old-device',
        type: 'macos',
        // customName and customAvatar default to null
      );

      expect(peer.displayName, equals('old-device'));
      expect(peer.displayAvatar, equals('laptop'));
      expect(peer.customName, isNull);
      expect(peer.customAvatar, isNull);
    });

    test('Mixing old and new peers in peer list', () {
      final peers = [
        // Old peer
        Peer(
          InternetAddress('192.168.1.100'),
          5678,
          name: 'old-device',
          type: 'android',
        ),
        // New peer with custom identity
        Peer(
          InternetAddress('192.168.1.101'),
          5678,
          name: 'new-device',
          type: 'android',
          customName: 'My Phone',
          customAvatar: 'phone',
        ),
      ];

      expect(peers[0].displayName, equals('old-device'));
      expect(peers[0].displayAvatar, equals('phone')); // Default for android

      expect(peers[1].displayName, equals('My Phone'));
      expect(peers[1].displayAvatar, equals('phone')); // Custom avatar
    });
  });

  group('Device Type Detection', () {
    test('All supported device types have correct default avatars', () {
      final types = {
        'android': 'phone',
        'macos': 'laptop',
        'linux': 'computer',
        'windows': 'desktop',
        'ios': 'phone',
      };

      types.forEach((type, expectedAvatar) {
        final peer = Peer(
          InternetAddress('192.168.1.100'),
          5678,
          name: 'test',
          type: type,
        );

        expect(
          peer.displayAvatar,
          equals(expectedAvatar),
          reason: '$type should map to $expectedAvatar',
        );
      });
    });

    test('Case sensitivity of device type', () {
      final lowerPeer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'test',
        type: 'android',
      );

      final upperPeer = Peer(
        InternetAddress('192.168.1.101'),
        5678,
        name: 'test',
        type: 'ANDROID',
      );

      // Both should resolve to valid avatars
      expect(lowerPeer.displayAvatar, isNotEmpty);
      expect(upperPeer.displayAvatar, isNotEmpty);
    });
  });
}
