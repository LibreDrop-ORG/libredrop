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
  group('Golden File Tests - Visual Regression', () {
    testWidgets('ConnectionStatusBanner - disconnected state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_disconnected.png'),
      );
    });

    testWidgets('ConnectionStatusBanner - connected state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: true,
              remoteEmoji: '📱',
              remoteIp: '192.168.1.100',
              negotiatedChunkSize: 1024,
              negotiatedBufferThreshold: 4096,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_connected.png'),
      );
    });

    testWidgets('ConnectionStatusBanner - error state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
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

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_error.png'),
      );
    });

    testWidgets('ConnectionStatusBanner - dark theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: true,
              remoteEmoji: '💻',
              remoteIp: '192.168.1.101',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_dark.png'),
      );
    });

    testWidgets('PulsingIcon - inactive state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: PulsingIcon(
                icon: Icons.refresh,
                isActive: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/pulsing_icon_inactive.png'),
      );
    });

    testWidgets('PulsingIcon - active state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
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

      // Pump a few times to capture animation midpoint
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/pulsing_icon_active.png'),
      );
    });
  });

  group('Golden Tests - Responsive Design', () {
    testWidgets('ConnectionStatusBanner - mobile size',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 2.0;

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

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_mobile.png'),
      );

      addTearDown(tester.view.reset);
    });

    testWidgets('ConnectionStatusBanner - tablet size',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: true,
              remoteEmoji: '💻',
              remoteIp: '192.168.1.100',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_tablet.png'),
      );

      addTearDown(tester.view.reset);
    });
  });

  group('Golden Tests - Animation States', () {
    testWidgets('ConnectionStatusBanner - animation start',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
            ),
          ),
        ),
      );

      // Capture at animation start
      await tester.pump();

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_animation_start.png'),
      );
    });

    testWidgets('ConnectionStatusBanner - animation midpoint',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
            ),
          ),
        ),
      );

      // Capture at animation midpoint
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_animation_mid.png'),
      );
    });
  });

  group('Golden Tests - Error States', () {
    testWidgets('Error banner with long message', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage:
                  'Failed to establish connection to the remote device after multiple attempts. Please check your network settings.',
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/error_banner_long_message.png'),
      );
    });

    testWidgets('Error banner without retry button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: ConnectionStatusBanner(
              connected: false,
              errorMessage: 'Network error occurred',
              onRetry: null, // No retry callback
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/error_banner_no_retry.png'),
      );
    });
  });

  group('Golden Tests - Accessibility', () {
    testWidgets('High contrast mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
              contrastLevel: 1.0, // Maximum contrast
            ),
          ),
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

      await expectLater(
        find.byType(ConnectionStatusBanner),
        matchesGoldenFile('goldens/connection_banner_high_contrast.png'),
      );
    });
  });

  group('Golden Tests - State Transitions', () {
    testWidgets('Transition from disconnected to connected',
        (WidgetTester tester) async {
      bool connected = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ConnectionStatusBanner(
                      connected: connected,
                      remoteEmoji: connected ? '📱' : null,
                      remoteIp: connected ? '192.168.1.100' : null,
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

      // Capture disconnected state
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/transition_disconnected.png'),
      );

      // Toggle to connected
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      // Capture connected state
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/transition_connected.png'),
      );
    });
  });
}
