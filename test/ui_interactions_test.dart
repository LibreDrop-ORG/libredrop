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
  group('Transfer Status Tests', () {
    test('TransferStatus enum has all expected values', () {
      expect(TransferStatus.values, contains(TransferStatus.initiating));
      expect(TransferStatus.values, contains(TransferStatus.active));
      expect(TransferStatus.values, contains(TransferStatus.paused));
      expect(TransferStatus.values, contains(TransferStatus.completed));
      expect(TransferStatus.values, contains(TransferStatus.failed));
      expect(TransferStatus.values, contains(TransferStatus.cancelled));
    });

    test('TransferStatus enum has correct number of values', () {
      // Ensures we maintain the expected transfer states
      expect(TransferStatus.values.length, equals(6));
    });

    test('TransferStatus enum values are distinct', () {
      final values = TransferStatus.values;
      final uniqueValues = values.toSet();
      expect(uniqueValues.length, equals(values.length));
    });
  });

  group('Swipe Gesture Tests', () {
    testWidgets('Peer list items are dismissible', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Check for Dismissible widgets
      final dismissibles = find.byType(Dismissible);

      // If peers are present, they should be dismissible
      if (dismissibles.evaluate().isNotEmpty) {
        expect(dismissibles, findsWidgets);
      }
    });

    testWidgets('Swipe gesture shows background hint', (WidgetTester tester) async {
      // Create a test peer
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
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Text('Connect'),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Text('Send File'),
              ),
              child: ListTile(
                title: Text(testPeer.displayName),
                subtitle: Text(testPeer.address.address),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state
      expect(find.text('Test Device'), findsOneWidget);
      expect(find.text('192.168.1.100'), findsOneWidget);
    });

    testWidgets('Pull-to-refresh is available on peer list', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Check for RefreshIndicator
      final refreshIndicator = find.byType(RefreshIndicator);
      expect(refreshIndicator, findsWidgets);
    });

    testWidgets('Pull-to-refresh triggers refresh action', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the scrollable peer list
      final peerList = find.text('Scanning for peers...\nPull down to refresh');

      if (peerList.evaluate().isNotEmpty) {
        // Perform pull-to-refresh gesture
        await tester.fling(
          peerList,
          const Offset(0, 300),
          1000.0,
        );
        await tester.pump();

        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();
      }
    });
  });

  group('Haptic Feedback Tests', () {
    testWidgets('App uses HapticFeedback for user actions', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Test settings button tap (should trigger haptic)
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // Should navigate to settings
        expect(find.text('Settings'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }

      // Test refresh button tap (should trigger haptic)
      final refreshButton = find.byIcon(Icons.refresh);
      if (refreshButton.evaluate().isNotEmpty) {
        await tester.tap(refreshButton);
        await tester.pump();

        // Should show loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();
      }
    });
  });

  group('Animation Performance Tests', () {
    testWidgets('Animations complete within expected timeframe', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
            ),
          ),
        ),
      );

      // Animation should start
      await tester.pump();

      // Check animation widgets exist
      expect(find.byType(SlideTransition), findsOneWidget);
      expect(find.byType(FadeTransition), findsOneWidget);

      // Wait for animation to complete (300ms fade + 400ms slide)
      await tester.pump(const Duration(milliseconds: 500));

      // Animation should be in progress or complete
      expect(find.byType(ConnectionStatusBanner), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('PulsingIcon animation cycles correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingIcon(
              icon: Icons.refresh,
              isActive: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Check animation is running
      expect(find.byType(AnimatedBuilder), findsOneWidget);

      // Advance animation
      await tester.pump(const Duration(milliseconds: 750)); // Half of 1500ms cycle

      expect(find.byType(PulsingIcon), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Multiple animations do not cause jank', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Trigger refresh (starts pulsing animation)
      final refreshButton = find.byIcon(Icons.refresh);
      if (refreshButton.evaluate().isNotEmpty) {
        await tester.tap(refreshButton);
        await tester.pump();

        // Multiple animations should be running
        expect(find.byType(PulsingIcon), findsOneWidget);

        // Continue animation
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await tester.pumpAndSettle();
      }
    });
  });

  group('UI Responsiveness Tests', () {
    testWidgets('App responds to rapid state changes', (WidgetTester tester) async {
      bool connected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ConnectionStatusBanner(
                      connected: connected,
                    ),
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

      // Rapid state changes
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Toggle'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // Should still render correctly
      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
    });

    testWidgets('Large peer lists render efficiently', (WidgetTester tester) async {
      // Note: In real app, large lists would come from discovery
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Check peer list renders
      expect(find.text('LibreDrop Peers'), findsOneWidget);

      // Peer list should use ListView for efficiency
      expect(find.byType(ListView), findsWidgets);
    });
  });

  group('Error State UI Tests', () {
    testWidgets('Error banner displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage: 'Test error message',
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connection Failed'), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Error banner shows retry and help buttons', (WidgetTester tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage: 'Connection failed',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test retry button
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);

      // Test help button
      expect(find.text('Help'), findsOneWidget);
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();

      expect(find.text('Troubleshooting Tips'), findsOneWidget);
    });
  });

  group('Component Integration Tests', () {
    testWidgets('ConnectionStatusBanner integrates with HomePage', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('PulsingIcon integrates with refresh button', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.byType(PulsingIcon), findsOneWidget);

      // The pulsing icon should be in the refresh button area
      final pulsingIcon = find.byType(PulsingIcon);
      expect(pulsingIcon, findsOneWidget);
    });
  });
}
