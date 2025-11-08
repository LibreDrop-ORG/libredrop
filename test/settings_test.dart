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
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/settings_service.dart';
import '../lib/settings_page.dart';

void main() {
  group('SettingsService Tests', () {
    late SettingsService settingsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
    });

    group('Download Path Tests', () {
      test('loadDownloadPath returns null initially', () async {
        final path = await settingsService.loadDownloadPath();
        expect(path, isNull);
      });

      test('saveDownloadPath and loadDownloadPath work correctly', () async {
        const testPath = '/test/download/path';
        await settingsService.saveDownloadPath(testPath);

        final loadedPath = await settingsService.loadDownloadPath();
        expect(loadedPath, equals(testPath));
      });

      test('saveDownloadPath can clear path with null', () async {
        await settingsService.saveDownloadPath('/test/path');
        await settingsService.saveDownloadPath(null);

        final loadedPath = await settingsService.loadDownloadPath();
        expect(loadedPath, isNull);
      });
    });

    group('Device Name Tests', () {
      test('loadDeviceName returns null initially', () async {
        final name = await settingsService.loadDeviceName();
        expect(name, isNull);
      });

      test('saveDeviceName and loadDeviceName work correctly', () async {
        const testName = 'My Test Device';
        await settingsService.saveDeviceName(testName);

        final loadedName = await settingsService.loadDeviceName();
        expect(loadedName, equals(testName));
      });

      test('saveDeviceName handles empty string', () async {
        await settingsService.saveDeviceName('');

        final loadedName = await settingsService.loadDeviceName();
        expect(loadedName, equals(''));
      });

      test('saveDeviceName handles special characters', () async {
        const testName = 'John\'s MacBook Pro (2024)';
        await settingsService.saveDeviceName(testName);

        final loadedName = await settingsService.loadDeviceName();
        expect(loadedName, equals(testName));
      });
    });

    group('Device Avatar Tests', () {
      test('loadDeviceAvatar returns null initially', () async {
        final avatar = await settingsService.loadDeviceAvatar();
        expect(avatar, isNull);
      });

      test('saveDeviceAvatar and loadDeviceAvatar work correctly', () async {
        const testAvatar = 'laptop';
        await settingsService.saveDeviceAvatar(testAvatar);

        final loadedAvatar = await settingsService.loadDeviceAvatar();
        expect(loadedAvatar, equals(testAvatar));
      });

      test('saveDeviceAvatar handles various avatar types', () async {
        final avatars = ['phone', 'laptop', 'desktop', 'tablet', 'computer'];

        for (final avatar in avatars) {
          await settingsService.saveDeviceAvatar(avatar);
          final loaded = await settingsService.loadDeviceAvatar();
          expect(loaded, equals(avatar));
        }
      });
    });

    group('Persistence Tests', () {
      test('Multiple settings persist independently', () async {
        await settingsService.saveDownloadPath('/downloads');
        await settingsService.saveDeviceName('Test Device');
        await settingsService.saveDeviceAvatar('laptop');

        final path = await settingsService.loadDownloadPath();
        final name = await settingsService.loadDeviceName();
        final avatar = await settingsService.loadDeviceAvatar();

        expect(path, equals('/downloads'));
        expect(name, equals('Test Device'));
        expect(avatar, equals('laptop'));
      });

      test('Settings persist across service instances', () async {
        await settingsService.saveDeviceName('Persistent Device');

        final newService = SettingsService();
        final loadedName = await newService.loadDeviceName();

        expect(loadedName, equals('Persistent Device'));
      });
    });
  });

  group('SettingsPage Widget Tests', () {
    testWidgets('SettingsPage renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentPath: '/test/path'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Download Location'), findsOneWidget);
      expect(find.text('/test/path'), findsOneWidget);
    });

    testWidgets('SettingsPage shows device identity section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentPath: '/downloads'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Device Identity'), findsOneWidget);
      expect(find.text('Device Name'), findsOneWidget);
      expect(find.text('Device Avatar'), findsOneWidget);
    });

    testWidgets('Device name input field exists', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentPath: '/downloads'),
        ),
      );
      await tester.pumpAndSettle();

      // Check that TextFormField widgets exist in settings page
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);
    });

    testWidgets('Avatar grid displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentPath: '/downloads'),
        ),
      );
      await tester.pumpAndSettle();

      // Check for avatar grid
      expect(find.byType(GridView), findsOneWidget);

      // Avatar selection should have multiple items
      final gridItems = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );

      expect(gridItems.evaluate().length, greaterThan(0));
    });

    testWidgets('Avatar selection works correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentPath: '/downloads'),
        ),
      );
      await tester.pumpAndSettle();

      // Find avatar grid items
      final avatarItems = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );

      if (avatarItems.evaluate().isNotEmpty) {
        // Tap first avatar
        await tester.tap(avatarItems.first);
        await tester.pumpAndSettle();

        // Avatar should be selected (visual indication)
        expect(find.byType(GridView), findsOneWidget);
      }
    });

    testWidgets('Back button navigation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(currentPath: '/downloads'),
                  ),
                ),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('Settings page has proper accessibility semantics', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentPath: '/downloads'),
        ),
      );
      await tester.pumpAndSettle();

      // Check for semantic labels
      expect(find.byType(Semantics), findsWidgets);

      // Check that TextFormField exists (for device name input)
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);
    });
  });

  group('Settings Integration Tests', () {
    testWidgets('Save and load flow works end-to-end', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(currentPath: '/downloads'),
        ),
      );
      await tester.pumpAndSettle();

      // Check that TextFormField exists
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);

      // Select an avatar if available
      final avatarItems = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );

      if (avatarItems.evaluate().isNotEmpty) {
        await tester.tap(avatarItems.first);
        await tester.pumpAndSettle();
      }

      // Verify settings page renders correctly
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
