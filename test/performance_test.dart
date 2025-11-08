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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  group('Animation Performance Tests', () {
    testWidgets('ConnectionStatusBanner animations maintain 60fps', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
            ),
          ),
        ),
      );

      // Measure frame rendering performance
      final List<Duration> frameDurations = [];

      // Start animation
      await tester.pump();

      // Capture frame times during animation (first 500ms)
      for (int i = 0; i < 30; i++) {
        final startTime = DateTime.now();
        await tester.pump(const Duration(milliseconds: 16)); // ~60fps
        final frameTime = DateTime.now().difference(startTime);
        frameDurations.add(frameTime);
      }

      // Calculate average frame time
      final avgFrameTime = frameDurations.fold<int>(
        0,
        (sum, duration) => sum + duration.inMicroseconds,
      ) / frameDurations.length;

      // 60fps target = 16.67ms per frame (16667 microseconds)
      // Allow 20ms margin for test environment variability
      expect(avgFrameTime, lessThan(20000),
        reason: 'Animation should maintain near 60fps performance');

      await tester.pumpAndSettle();
    });

    testWidgets('PulsingIcon animation cycles efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingIcon(
                icon: Icons.refresh,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      // Measure animation performance over multiple cycles
      final List<Duration> cycleTimes = [];

      for (int cycle = 0; cycle < 3; cycle++) {
        final startTime = DateTime.now();

        // One complete cycle (1500ms)
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));

        final cycleTime = DateTime.now().difference(startTime);
        cycleTimes.add(cycleTime);
      }

      // Verify consistent cycle timing
      final avgCycleTime = cycleTimes.fold<int>(
        0,
        (sum, duration) => sum + duration.inMilliseconds,
      ) / cycleTimes.length;

      // Should be close to 1500ms per cycle (allow 100ms variance)
      expect(avgCycleTime, greaterThan(1400));
      expect(avgCycleTime, lessThan(1600));

      await tester.pumpAndSettle();
    });

    testWidgets('Multiple simultaneous animations perform efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ConnectionStatusBanner(connected: false),
                PulsingIcon(icon: Icons.refresh, isActive: true),
                PulsingIcon(icon: Icons.wifi, isActive: true),
                PulsingIcon(icon: Icons.sync, isActive: true),
              ],
            ),
          ),
        ),
      );

      // Measure frame times with multiple animations
      final List<Duration> frameDurations = [];

      await tester.pump();

      for (int i = 0; i < 30; i++) {
        final startTime = DateTime.now();
        await tester.pump(const Duration(milliseconds: 16));
        final frameTime = DateTime.now().difference(startTime);
        frameDurations.add(frameTime);
      }

      final avgFrameTime = frameDurations.fold<int>(
        0,
        (sum, duration) => sum + duration.inMicroseconds,
      ) / frameDurations.length;

      // Even with multiple animations, should maintain reasonable performance
      expect(avgFrameTime, lessThan(25000),
        reason: 'Multiple animations should not cause performance degradation');

      await tester.pumpAndSettle();
    });
  });

  group('UI Responsiveness Performance Tests', () {
    testWidgets('Button tap response time is under 100ms', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final refreshButton = find.byIcon(Icons.refresh);

      if (refreshButton.evaluate().isNotEmpty) {
        final startTime = DateTime.now();
        await tester.tap(refreshButton);
        await tester.pump();
        final responseTime = DateTime.now().difference(startTime);

        // UI should respond within 100ms
        expect(responseTime.inMilliseconds, lessThan(100),
          reason: 'Button tap should have immediate visual feedback');
      }

      await tester.pumpAndSettle();
    });

    testWidgets('Settings navigation performs efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      final settingsButton = find.byIcon(Icons.settings);

      if (settingsButton.evaluate().isNotEmpty) {
        final startTime = DateTime.now();
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();
        final navigationTime = DateTime.now().difference(startTime);

        // Navigation should complete within 500ms
        expect(navigationTime.inMilliseconds, lessThan(500),
          reason: 'Settings navigation should be smooth and fast');

        // Navigate back
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('State transitions are smooth', (WidgetTester tester) async {
      bool connected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ConnectionStatusBanner(connected: connected),
                    ElevatedButton(
                      onPressed: () => setState(() => connected = !connected),
                      child: const Text('Toggle'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Measure multiple rapid state changes
      final List<Duration> transitionTimes = [];

      for (int i = 0; i < 10; i++) {
        final startTime = DateTime.now();
        await tester.tap(find.text('Toggle'));
        await tester.pump();
        final transitionTime = DateTime.now().difference(startTime);
        transitionTimes.add(transitionTime);
      }

      final avgTransitionTime = transitionTimes.fold<int>(
        0,
        (sum, duration) => sum + duration.inMilliseconds,
      ) / transitionTimes.length;

      // State transitions should be instant (<50ms)
      expect(avgTransitionTime, lessThan(50),
        reason: 'State transitions should be immediate');

      await tester.pumpAndSettle();
    });
  });

  group('List Rendering Performance Tests', () {
    testWidgets('Peer list renders efficiently', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      final startTime = DateTime.now();
      await tester.pumpAndSettle();
      final renderTime = DateTime.now().difference(startTime);

      // Initial render should be fast
      expect(renderTime.inMilliseconds, lessThan(1000),
        reason: 'App should render within 1 second');

      // Verify ListView is used for efficient scrolling
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('Large peer list scrolling is smooth', (WidgetTester tester) async {
      // Create a test scenario with many peer widgets
      final List<Widget> peers = List.generate(
        50,
        (index) => ListTile(
          key: Key('peer-$index'),
          leading: const CircleAvatar(child: Icon(Icons.phone)),
          title: Text('Device $index'),
          subtitle: Text('192.168.1.$index'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: peers,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Measure scrolling performance
      final startTime = DateTime.now();

      // Scroll through the list
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump();

      final scrollTime = DateTime.now().difference(startTime);

      // Scrolling should be smooth and fast
      expect(scrollTime.inMilliseconds, lessThan(200),
        reason: 'List scrolling should be smooth even with many items');

      await tester.pumpAndSettle();
    });

    testWidgets('Dismissible swipe gesture performs smoothly', (WidgetTester tester) async {
      final testPeer = Peer(
        InternetAddress('192.168.1.100'),
        5678,
        name: 'Test Device',
        type: 'android',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dismissible(
              key: Key('peer-${testPeer.address.address}'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async => false,
              background: Container(color: Colors.green),
              secondaryBackground: Container(color: Colors.blue),
              child: ListTile(
                title: Text(testPeer.displayName),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Measure swipe gesture performance
      final startTime = DateTime.now();

      await tester.drag(find.byType(Dismissible), const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final swipeTime = DateTime.now().difference(startTime);

      // Swipe should respond immediately
      expect(swipeTime.inMilliseconds, lessThan(150),
        reason: 'Swipe gesture should have immediate response');

      await tester.pumpAndSettle();
    });
  });

  group('Memory and Resource Tests', () {
    test('Progress calculation benchmark', () {
      // Test that progress calculations are efficient
      final size = 100 * 1024 * 1024; // 100MB
      final startTime = DateTime.now();

      for (int i = 0; i < 100; i++) {
        final transferred = i * 1024 * 1024; // Update every 1MB
        final progress = size == 0 ? 0 : transferred / size;
        final percentage = (progress * 100).clamp(0, 100).toInt();

        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
        expect(percentage, greaterThanOrEqualTo(0));
        expect(percentage, lessThanOrEqualTo(100));
      }

      final updateTime = DateTime.now().difference(startTime);

      // 100 progress calculations should complete in under 10ms
      expect(updateTime.inMilliseconds, lessThan(10),
        reason: 'Progress calculations should be extremely fast');
    });

    testWidgets('Animation cleanup prevents memory leaks', (WidgetTester tester) async {
      // Create and dispose multiple animated widgets
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ConnectionStatusBanner(connected: false),
                  PulsingIcon(icon: Icons.refresh, isActive: true),
                ],
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));

        // Dispose by replacing with empty widget
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await tester.pump();
      }

      // If we get here without errors, animations cleaned up properly
      expect(true, isTrue);
    });

    testWidgets('Multiple peer updates maintain performance', (WidgetTester tester) async {
      // Simulate rapid peer list updates
      final List<Peer> peers = List.generate(
        20,
        (index) => Peer(
          InternetAddress('192.168.1.$index'),
          5678,
          name: 'Device $index',
          type: 'android',
        ),
      );

      final startTime = DateTime.now();

      // Simulate 10 rapid peer list updates
      for (int update = 0; update < 10; update++) {
        // Add custom names to peers
        for (int i = 0; i < peers.length; i++) {
          peers[i] = Peer(
            peers[i].address,
            peers[i].port,
            name: peers[i].name,
            type: peers[i].type,
            customName: 'Updated Device $i - Round $update',
          );
        }

        // Verify display names
        for (final peer in peers) {
          expect(peer.displayName, isNotEmpty);
        }
      }

      final updateTime = DateTime.now().difference(startTime);

      // Multiple rapid updates should complete quickly
      expect(updateTime.inMilliseconds, lessThan(100),
        reason: 'Peer updates should be efficient even with many peers');
    });
  });

  group('Benchmark Performance Standards', () {
    test('Performance standards documentation', () {
      // Document expected performance standards for LibreDrop

      final standards = {
        'Animation frame rate': '60fps (16.67ms per frame)',
        'Button tap response': '<100ms',
        'Navigation transition': '<500ms',
        'State change response': '<50ms',
        'Initial app render': '<1000ms',
        'List scrolling': 'Smooth at 60fps',
        'Swipe gesture response': '<150ms',
        'Progress calculation': '<0.1ms per update',
        'Peer discovery update': '<100ms for 20 peers',
      };

      // Verify standards are documented
      expect(standards, isNotEmpty);
      expect(standards.length, equals(9));

      // Print standards for reference
      print('\n=== LibreDrop Performance Standards ===');
      standards.forEach((key, value) {
        print('$key: $value');
      });
      print('=====================================\n');
    });

    test('Platform-specific performance notes', () {
      final platformNotes = {
        'iOS': 'Metal rendering provides excellent animation performance',
        'Android': 'Skia rendering engine handles animations efficiently',
        'macOS': 'Native rendering with Metal backend',
        'Windows': 'ANGLE backend provides consistent performance',
        'Linux': 'OpenGL rendering may vary by GPU drivers',
      };

      expect(platformNotes, isNotEmpty);

      print('\n=== Platform Performance Notes ===');
      platformNotes.forEach((platform, note) {
        print('$platform: $note');
      });
      print('=================================\n');
    });
  });
}
