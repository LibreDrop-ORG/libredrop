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
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  group('LibreDrop Integration Tests', () {
    testWidgets('Full app startup and navigation flow', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify main components are present
      expect(find.text('LibreDrop Peers'), findsOneWidget);
      expect(find.text('File Transfers'), findsOneWidget);
      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Test settings navigation
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      // Navigate back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('LibreDrop Peers'), findsOneWidget);
    });

    testWidgets('Peer discovery and connection flow simulation', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Test manual IP connection dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Connect to IP'), findsOneWidget);
      expect(find.text('Enter IP address'), findsOneWidget);

      // Enter invalid IP and test validation
      await tester.enterText(find.byType(TextFormField), '192.168.1');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid IPv4 address'), findsOneWidget);

      // Enter valid IP
      await tester.enterText(find.byType(TextFormField), '192.168.1.100');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.text('Connect to IP'), findsNothing);
    });

    testWidgets('Error state and recovery flow', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Simulate connection error by trying to connect to invalid IP
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '192.168.1.255');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // Wait for connection attempt to fail (in real scenario)
      // Since we can't actually connect in tests, we'll test the UI components
      
      // Verify refresh functionality
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Accessibility focus traversal', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Test tab navigation through focusable elements
      final settingsButton = find.byIcon(Icons.settings);
      final addButton = find.byIcon(Icons.add);
      final refreshButton = find.byIcon(Icons.refresh);
      final sendButton = find.byType(FloatingActionButton);

      expect(settingsButton, findsOneWidget);
      expect(addButton, findsOneWidget);
      expect(refreshButton, findsOneWidget);
      expect(sendButton, findsOneWidget);

      // Verify buttons are tappable
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(addButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Animation performance and completion', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Test PulsingIcon animation performance
      expect(find.byType(PulsingIcon), findsOneWidget);

      // Trigger refresh to activate pulsing
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump(); // Start animation

      // Verify animation is running
      expect(find.byType(PulsingIcon), findsOneWidget);
      
      // Wait for animation completion
      await tester.pumpAndSettle();

      // Animation should stop after refresh completes
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Theme and responsive design', (WidgetTester tester) async {
      // Test light theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);

      // Test dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
    });

    testWidgets('Screen size adaptation', (WidgetTester tester) async {
      // Test small screen
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('LibreDrop Peers'), findsOneWidget);
      expect(find.text('File Transfers'), findsOneWidget);

      // Test large screen
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('LibreDrop Peers'), findsOneWidget);
      expect(find.text('File Transfers'), findsOneWidget);

      addTearDown(tester.view.reset);
    });

    group('Error Recovery Tests', () {
      testWidgets('Handles widget rebuild during animation', (WidgetTester tester) async {
        bool showError = false;
        
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      ConnectionStatusBanner(
                        connected: false,
                        errorMessage: showError ? 'Connection failed' : null,
                        onRetry: () => setState(() => showError = false),
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => showError = !showError),
                        child: Text('Toggle Error'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Toggle error state during animation
        await tester.tap(find.text('Toggle Error'));
        await tester.pump();
        
        expect(find.text('Connection Failed'), findsOneWidget);
        
        // Toggle back quickly
        await tester.tap(find.text('Toggle Error'));
        await tester.pump();
        
        await tester.pumpAndSettle();
        expect(find.text('LibreDrop - Ready for connections'), findsOneWidget);
      });

      testWidgets('Handles rapid state changes gracefully', (WidgetTester tester) async {
        bool isActive = false;
        
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      PulsingIcon(
                        icon: Icons.wifi,
                        isActive: isActive,
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => isActive = !isActive),
                        child: Text('Toggle'),
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
          await tester.pump();
        }

        await tester.pumpAndSettle();
        expect(find.byType(PulsingIcon), findsOneWidget);
      });
    });
  });
}