import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dashboard/dashboard.dart';

void main() {
  group('Dashboard Resize & Scale in Edit Mode', () {
    testWidgets('should enable editing mode', (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'resizable_item', width: 2, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: Key(item.identifier),
                color: Colors.blue,
                child: Text(item.identifier),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                resizeCursorSide: 20,
                longPressEnabled: true,
                panEnabled: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);

      // Sprawdź czy kontroler pozwala na włączenie trybu edycji
      expect(() => controller.isEditing, returnsNormally);
    });

    testWidgets('should handle custom resize cursor size',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'cursor_test', width: 3, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Testujemy różne rozmiary kursora resize
      final cursorSizes = [5.0, 10.0, 20.0, 30.0];

      for (double cursorSize in cursorSizes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  key: Key('cursor_test_${cursorSize.toInt()}'),
                  color: Colors.red,
                  child: Text('Cursor: ${cursorSize.toInt()}'),
                ),
                dashboardItemController: controller,
                editModeSettings: EditModeSettings(
                  resizeCursorSide: cursorSize,
                  longPressEnabled: true,
                  panEnabled: true,
                  paintBackgroundLines: true,
                  fillEditingBackground: true,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
        expect(find.byKey(Key('cursor_test_${cursorSize.toInt()}')),
            findsOneWidget);
      }
    });

    testWidgets('should handle custom resize handle builder',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'handle_test', width: 2, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: Key(item.identifier),
                color: Colors.green,
                child: Text(item.identifier),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                resizeHandleBuilder: (context, item, isEditing) {
                  return Container(
                    key: const Key('custom_resize_handle'),
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.drag_handle,
                      color: Colors.white,
                      size: 16,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
      expect(find.byKey(const Key('handle_test')), findsOneWidget);
    });

    testWidgets('should handle shrink on move settings',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'shrink_test', width: 2, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z shrinkOnMove = true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: const Key('shrink_enabled'),
                color: Colors.purple,
                child: const Text('Shrink Enabled'),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                shrinkOnMove: true,
                draggableOutside: true,
                autoScroll: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('shrink_enabled')), findsOneWidget);

      // Test z shrinkOnMove = false
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: const Key('shrink_disabled'),
                color: Colors.teal,
                child: const Text('Shrink Disabled'),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                shrinkOnMove: false,
                draggableOutside: false,
                autoScroll: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('shrink_disabled')), findsOneWidget);
    });

    testWidgets('should handle animation settings for scaling',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'anim_test', width: 1, height: 1),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z różnymi ustawieniami animacji
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: Key(item.identifier),
                color: Colors.amber,
                child: Text(item.identifier),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                duration: const Duration(milliseconds: 500),
                curve: Curves.bounceInOut,
                paintBackgroundLines: true,
                fillEditingBackground: true,
              ),
              animateEverytime: true,
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
      expect(find.byKey(const Key('anim_test')), findsOneWidget);
    });

    testWidgets('should handle background style in edit mode',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'bg_test', width: 2, height: 1),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: Key(item.identifier),
                color: Colors.lime,
                child: Text(item.identifier),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                paintBackgroundLines: true,
                fillEditingBackground: true,
                backgroundStyle: const EditModeBackgroundStyle(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
      expect(find.byKey(const Key('bg_test')), findsOneWidget);
    });

    testWidgets('should handle gesture settings', (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'gesture_test', width: 2, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z włączonymi gestami
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: const Key('gestures_enabled'),
                color: Colors.indigo,
                child: const Text('Gestures Enabled'),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                longPressEnabled: true,
                panEnabled: true,
                resizeCursorSide: 15,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('gestures_enabled')), findsOneWidget);

      // Test z wyłączonymi gestami
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: const Key('gestures_disabled'),
                color: Colors.brown,
                child: const Text('Gestures Disabled'),
              ),
              dashboardItemController: controller,
              editModeSettings: EditModeSettings(
                longPressEnabled: false,
                panEnabled: false,
                resizeCursorSide: 0,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('gestures_disabled')), findsOneWidget);
    });
  });

  group('Edit Mode Settings Model', () {
    test('should create EditModeSettings with default values', () {
      final settings = EditModeSettings();

      expect(settings.resizeCursorSide, 10);
      expect(settings.paintBackgroundLines, true);
      expect(settings.fillEditingBackground, true);
      expect(settings.longPressEnabled, true);
      expect(settings.panEnabled, true);
      expect(settings.shrinkOnMove, true);
      expect(settings.draggableOutside, true);
      expect(settings.autoScroll, true);
      expect(settings.curve, Curves.easeOut);
      expect(settings.resizeHandleBuilder, isNull);
    });

    test('should create EditModeSettings with custom values', () {
      final settings = EditModeSettings(
        resizeCursorSide: 20,
        paintBackgroundLines: false,
        fillEditingBackground: false,
        longPressEnabled: false,
        panEnabled: false,
        shrinkOnMove: false,
        draggableOutside: false,
        autoScroll: false,
        curve: Curves.linear,
        duration: const Duration(milliseconds: 1000),
      );

      expect(settings.resizeCursorSide, 20);
      expect(settings.paintBackgroundLines, false);
      expect(settings.fillEditingBackground, false);
      expect(settings.longPressEnabled, false);
      expect(settings.panEnabled, false);
      expect(settings.shrinkOnMove, false);
      expect(settings.draggableOutside, false);
      expect(settings.autoScroll, false);
      expect(settings.curve, Curves.linear);
      expect(settings.duration, const Duration(milliseconds: 1000));
    });

    test('should handle custom resize handle builder', () {
      Widget customResizeHandle(
          BuildContext context, DashboardItem item, bool isEditing) {
        return Container(
          width: 24,
          height: 24,
          color: Colors.red,
        );
      }

      final settings = EditModeSettings(
        resizeHandleBuilder: customResizeHandle,
      );

      expect(settings.resizeHandleBuilder, isNotNull);
      expect(settings.resizeHandleBuilder, equals(customResizeHandle));
    });
  });

  group('EditModeBackgroundStyle Model', () {
    test('should create EditModeBackgroundStyle with defaults', () {
      const style = EditModeBackgroundStyle();
      expect(style, isNotNull);
    });

    test('should handle EditModeBackgroundStyle creation', () {
      expect(() => const EditModeBackgroundStyle(), returnsNormally);
    });
  });
}
