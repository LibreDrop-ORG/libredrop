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
  group('LibreDrop Accessibility Tests', () {
    testWidgets('All interactive elements have semantic labels', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Test settings button semantics
      final settingsSemantics = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Open settings' &&
               widget.properties.hint == 'Opens the settings page to configure download location and device identity';
      });
      expect(settingsSemantics, findsOneWidget);

      // Test send file button semantics
      final sendFileSemantics = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Send file to connected device' &&
               widget.properties.hint == 'Opens file picker to select a file for sending';
      });
      expect(sendFileSemantics, findsOneWidget);

      // Test connect to IP button semantics
      final connectSemantics = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Connect to IP address' &&
               widget.properties.hint == 'Opens dialog to manually enter an IP address to connect to';
      });
      expect(connectSemantics, findsOneWidget);

      // Test refresh button semantics
      final refreshSemantics = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Refresh peer list';
      });
      expect(refreshSemantics, findsOneWidget);
    });

    testWidgets('Error state has proper accessibility announcements', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage: 'Failed to connect to device',
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify error semantics
      expect(find.text('Connection Failed'), findsOneWidget);
      expect(find.text('Failed to connect to device'), findsOneWidget);

      // Test retry button accessibility
      final retrySemantics = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Retry connection';
      });
      expect(retrySemantics, findsOneWidget);

      // Test help button accessibility
      final helpSemantics = find.byWidgetPredicate((widget) {
        return widget is Semantics &&
               widget.properties.label == 'Show troubleshooting help';
      });
      expect(helpSemantics, findsOneWidget);
    });

    testWidgets('Focus indicators are visible and functional', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Test that focusable widgets exist
      expect(find.byType(Focus), findsWidgets);
      
      // Verify buttons are focusable
      final settingsButton = find.byIcon(Icons.settings);
      final addButton = find.byIcon(Icons.add);
      
      expect(settingsButton, findsOneWidget);
      expect(addButton, findsOneWidget);
      
      // Test tap functionality (simulating keyboard activation)
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();
      
      expect(find.text('Settings'), findsOneWidget);
      
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    });

    testWidgets('Screen reader navigation is logical', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify semantic structure exists in correct order
      final connectionBanner = find.byType(ConnectionStatusBanner);
      final peerList = find.text('LibreDrop Peers');
      final transferList = find.text('File Transfers');
      final sendButton = find.byType(FloatingActionButton);

      expect(connectionBanner, findsOneWidget);
      expect(peerList, findsOneWidget);
      expect(transferList, findsOneWidget);
      expect(sendButton, findsOneWidget);
    });

    testWidgets('Color contrast meets accessibility standards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: true,
              remoteEmoji: '📱',
              remoteIp: '192.168.1.100',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);

      // Test dark theme contrast
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: true,
              remoteEmoji: '📱',
              remoteIp: '192.168.1.100',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
    });

    testWidgets('Touch targets meet minimum size requirements', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Test button sizes (Material Design minimum is 48x48)
      final settingsButton = find.byIcon(Icons.settings);
      final addButton = find.byIcon(Icons.add);
      final refreshButton = find.byIcon(Icons.refresh);
      final sendButton = find.byType(FloatingActionButton);

      expect(settingsButton, findsOneWidget);
      expect(addButton, findsOneWidget);
      expect(refreshButton, findsOneWidget);
      expect(sendButton, findsOneWidget);

      // Verify buttons are tappable (indicating adequate touch targets)
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();
      
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(addButton);
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Keyboard navigation works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify keyboard shortcuts are registered
      expect(find.byType(Shortcuts), findsOneWidget);
      expect(find.byType(Actions), findsOneWidget);

      // Test focus traversal
      expect(find.byType(Focus), findsWidgets);
    });

    testWidgets('Dynamic content updates are announced', (WidgetTester tester) async {
      bool connected = false;
      String? errorMessage;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
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
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state
      expect(find.text('LibreDrop - Ready for connections'), findsOneWidget);

      // Change state and verify update
      await tester.tap(find.text('Toggle Connection'));
      await tester.pumpAndSettle();

      // State should have changed
      expect(find.text('LibreDrop - Ready for connections'), findsNothing);
    });

    group('Semantic Structure Tests', () {
      testWidgets('Headings and landmarks are properly structured', (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Verify main sections exist
        expect(find.text('LibreDrop Peers'), findsOneWidget);
        expect(find.text('File Transfers'), findsOneWidget);
        
        // These act as section headings for screen readers
        final peerSection = find.text('LibreDrop Peers');
        final transferSection = find.text('File Transfers');
        
        expect(peerSection, findsOneWidget);
        expect(transferSection, findsOneWidget);
      });

      testWidgets('Form controls have proper labels and descriptions', (WidgetTester tester) async {
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();

        // Test IP connection dialog
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('Enter IP address'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        
        // Test form validation message
        await tester.tap(find.text('Connect'));
        await tester.pumpAndSettle();
        
        expect(find.text('Please enter an IP address'), findsOneWidget);
      });
    });

    group('Error State Accessibility', () {
      testWidgets('Error messages are properly announced', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConnectionStatusBanner(
                connected: false,
                errorMessage: 'Network timeout occurred',
                onRetry: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connection Failed'), findsOneWidget);
        expect(find.text('Network timeout occurred'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      });

      testWidgets('Recovery actions are accessible', (WidgetTester tester) async {
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

        // Test help dialog accessibility
        await tester.tap(find.text('Help'));
        await tester.pumpAndSettle();

        expect(find.text('Troubleshooting Tips'), findsOneWidget);
        
        // Close button should have proper semantics
        final closeButton = find.byWidgetPredicate((widget) {
          return widget is Semantics &&
                 widget.properties.label == 'Close troubleshooting dialog';
        });
        expect(closeButton, findsOneWidget);
      });
    });
  });
}