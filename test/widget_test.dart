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
  group('LibreDrop UI Components Tests', () {
    testWidgets('ConnectionStatusBanner shows connected state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: true,
              remoteEmoji: '🖥️',
              remoteIp: '192.168.1.100',
              negotiatedChunkSize: 1024,
              negotiatedBufferThreshold: 4096,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connected to 🖥️ 192.168.1.100'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.text('| WebRTC: chunk 1024, buffer 4096'), findsOneWidget);
    });

    testWidgets('ConnectionStatusBanner shows disconnected state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LibreDrop - Ready for connections'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });

    testWidgets('ConnectionStatusBanner shows error state with retry button', (WidgetTester tester) async {
      bool retryPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage: 'Failed to connect to 192.168.1.100',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Connection Failed'), findsOneWidget);
      expect(find.text('Failed to connect to 192.168.1.100'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets('ConnectionStatusBanner shows troubleshooting dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage: 'Connection failed',
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();

      expect(find.text('Troubleshooting Tips'), findsOneWidget);
      expect(find.text('• Make sure both devices are on the same WiFi network'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Troubleshooting Tips'), findsNothing);
    });

    testWidgets('PulsingIcon animates when active', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingIcon(
              icon: Icons.wifi,
              isActive: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byType(AnimatedBuilder), findsOneWidget);
      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('PulsingIcon shows static icon when inactive', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulsingIcon(
              icon: Icons.wifi,
              isActive: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byType(AnimatedBuilder), findsNothing);
      expect(find.byType(Transform), findsNothing);
    });

    testWidgets('ConnectionStatusBanner has proper accessibility semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage: 'Connection failed',
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test retry button semantics
      final retryButton = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Retry connection' &&
               widget.properties.hint == 'Attempts to reconnect to the previously attempted device';
      });
      expect(retryButton, findsOneWidget);

      // Test help button semantics
      final helpButton = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Show troubleshooting help' &&
               widget.properties.hint == 'Opens a dialog with connection troubleshooting tips';
      });
      expect(helpButton, findsOneWidget);
    });

    testWidgets('ConnectionStatusBanner animation transitions work', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
            ),
          ),
        ),
      );

      await tester.pump();
      
      // Verify initial fade and slide animations exist
      expect(find.byType(SlideTransition), findsOneWidget);
      expect(find.byType(FadeTransition), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Home page shows peer list title', (WidgetTester tester) async {
      // Build the app and trigger a frame.
      await tester.pumpWidget(const MyApp());

      // Verify that the title is present.
      expect(find.text('LibreDrop Peers'), findsOneWidget);
    });

    group('Animation Integration Tests', () {
      testWidgets('ConnectionStatusBanner animates state changes', (WidgetTester tester) async {
        bool connected = false;
        String? errorMessage;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      ConnectionStatusBanner(
                        connected: connected,
                        errorMessage: errorMessage,
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          connected = !connected;
                          errorMessage = connected ? null : 'Connection failed';
                        }),
                        child: Text('Toggle Connection'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initial state
        expect(find.text('LibreDrop - Ready for connections'), findsOneWidget);

        // Trigger state change
        await tester.tap(find.text('Toggle Connection'));
        await tester.pump(); // Start animation

        // Verify animation widgets are present during transition
        expect(find.byType(SlideTransition), findsOneWidget);
        expect(find.byType(FadeTransition), findsOneWidget);

        await tester.pumpAndSettle(); // Complete animation
      });

      testWidgets('PulsingIcon starts and stops animation correctly', (WidgetTester tester) async {
        bool isActive = false;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      PulsingIcon(
                        icon: Icons.wifi_find,
                        isActive: isActive,
                      ),
                      ElevatedButton(
                        onPressed: () => setState(() => isActive = !isActive),
                        child: Text('Toggle Animation'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Start animation
        await tester.tap(find.text('Toggle Animation'));
        await tester.pump();

        // Verify animation is running
        expect(find.byType(AnimatedBuilder), findsOneWidget);
        
        // Stop animation
        await tester.tap(find.text('Toggle Animation'));
        await tester.pumpAndSettle();

        // Verify animation stopped
        expect(find.byType(AnimatedBuilder), findsNothing);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('ConnectionStatusBanner handles null values gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConnectionStatusBanner(
                connected: false,
                remoteEmoji: null,
                remoteIp: null,
                negotiatedChunkSize: null,
                negotiatedBufferThreshold: null,
                errorMessage: null,
                onRetry: null,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('LibreDrop - Ready for connections'), findsOneWidget);
        expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
      });

      testWidgets('PulsingIcon handles color edge cases', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PulsingIcon(
                icon: Icons.error,
                isActive: true,
                activeColor: null, // Should fallback to theme color
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.error), findsOneWidget);
      });
    });
  });
}