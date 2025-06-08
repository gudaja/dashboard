import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dashboard/dashboard.dart';

void main() {
  group('Dashboard Widget', () {
    testWidgets('should create dashboard with basic parameters',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 2, height: 2),
        DashboardItem(identifier: 'item2', width: 3, height: 1),
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
              slotCount: 4,
            ),
          ),
        ),
      );

      // Sprawdzamy czy dashboard się poprawnie renderuje
      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);

      // Sprawdzamy czy elementy zostały wyrenderowane
      expect(find.byKey(const Key('item1')), findsOneWidget);
      expect(find.byKey(const Key('item2')), findsOneWidget);
    });

    testWidgets('should handle empty items list', (WidgetTester tester) async {
      final controller = DashboardItemController<DashboardItem>(items: []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: Key(item.identifier),
                child: Text(item.identifier),
              ),
              dashboardItemController: controller,
              slotCount: 4,
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
    });

    testWidgets('should handle different slot counts',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 1, height: 1),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z 2 slotami
      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(key: Key(item.identifier)),
            dashboardItemController: controller,
            slotCount: 2,
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);

      // Test z 8 slotami (domyślna wartość)
      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(key: Key(item.identifier)),
            dashboardItemController: controller,
            slotCount: 8,
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
    });

    testWidgets('should handle custom spacing', (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 2, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(key: Key(item.identifier)),
            dashboardItemController: controller,
            horizontalSpace: 16.0,
            verticalSpace: 20.0,
            padding: const EdgeInsets.all(12.0),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
    });

    testWidgets('should handle custom slot dimensions',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 1, height: 1),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z aspect ratio
      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(key: Key(item.identifier)),
            dashboardItemController: controller,
            slotAspectRatio: 1.5,
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);

      // Test z fixed height
      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(key: Key(item.identifier)),
            dashboardItemController: controller,
            slotHeight: 100.0,
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
    });

    testWidgets('should handle dashboard with disabled columns',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(
            identifier: 'item1', width: 2, height: 2, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'item2', width: 2, height: 1, startX: 3, startY: 0),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z wyłączoną kolumną 1 i 2 (ukryte kompletnie)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: Key(item.identifier),
                color: Colors.red,
                child: Text(item.identifier),
              ),
              dashboardItemController: controller,
              slotCount: 6,
              virtualColumnsConfig: const VirtualColumnsConfig.hidden(
                disabledColumns: [1, 2],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
      expect(find.byKey(const Key('item1')), findsOneWidget);
      expect(find.byKey(const Key('item2')), findsOneWidget);
    });

    testWidgets('should handle dashboard with visible disabled columns',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(
            identifier: 'item1', width: 1, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'item2', width: 1, height: 1, startX: 3, startY: 0),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z wyłączoną kolumną 1, ale widoczną (5% szerokości)
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
              slotCount: 4,
              virtualColumnsConfig: const VirtualColumnsConfig.visible(
                disabledColumns: [1],
                disabledColumnWidth: 0.05, // 5% szerokości
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
      expect(find.byKey(const Key('item1')), findsOneWidget);
      expect(find.byKey(const Key('item2')), findsOneWidget);
    });

    testWidgets('should handle dashboard with custom disabled column width',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 1, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test z wyłączonymi kolumnami o różnych szerokościach
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
              slotCount: 8,
              virtualColumnsConfig: const VirtualColumnsConfig(
                disabledColumns: [2, 4, 6],
                disabledColumnWidth:
                    0.1, // 10% szerokości na każdą wyłączoną kolumnę
                showDisabledColumns: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
      expect(find.byKey(const Key('item1')), findsOneWidget);
    });
  });

  group('Dashboard with Storage Delegate', () {
    testWidgets('should work with storage delegate',
        (WidgetTester tester) async {
      final storageDelegate = TestStorageDelegate();
      final controller = DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: storageDelegate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(
              key: Key(item.identifier),
              child: Text(item.identifier),
            ),
            dashboardItemController: controller,
          ),
        ),
      );

      // Dashboard powinien się poprawnie załadować z delegate
      await tester.pumpAndSettle();
      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
    });

    testWidgets('should handle loading state', (WidgetTester tester) async {
      final storageDelegate = AsyncTestStorageDelegate();
      final controller = DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: storageDelegate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(key: Key(item.identifier)),
            dashboardItemController: controller,
            loadingPlaceholder:
                const CircularProgressIndicator(key: Key('loading')),
          ),
        ),
      );

      // Sprawdzamy stan loading
      expect(find.byKey(const Key('loading')), findsOneWidget);

      // Czekamy na załadowanie
      await tester.pumpAndSettle();

      // Loading powinien zniknąć
      expect(find.byKey(const Key('loading')), findsNothing);
    });

    testWidgets('should handle empty state', (WidgetTester tester) async {
      final storageDelegate = TestStorageDelegate();
      final controller = DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: storageDelegate,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Dashboard<DashboardItem>(
            itemBuilder: (item) => Container(key: Key(item.identifier)),
            dashboardItemController: controller,
            emptyPlaceholder: const Text('Brak elementów', key: Key('empty')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Sprawdzamy czy wyświetla się empty state
      expect(find.byKey(const Key('empty')), findsOneWidget);
    });
  });

  group('EditModeSettings', () {
    test('should create EditModeSettings with defaults', () {
      final settings = EditModeSettings();
      expect(settings, isNotNull);
    });
  });
}

// Mock storage delegate dla testów synchronicznych
class TestStorageDelegate extends DashboardItemStorageDelegate<DashboardItem> {
  @override
  bool get cacheItems => true;

  @override
  bool get layoutsBySlotCount => false;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) {
    return <DashboardItem>[];
  }

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {
    // Mock implementation
  }

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {
    // Mock implementation
  }

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {
    // Mock implementation
  }
}

// Mock storage delegate dla testów asynchronicznych
class AsyncTestStorageDelegate
    extends DashboardItemStorageDelegate<DashboardItem> {
  @override
  bool get cacheItems => true;

  @override
  bool get layoutsBySlotCount => false;

  @override
  Future<List<DashboardItem>> getAllItems(int slotCount) async {
    // Symulujemy opóźnienie ładowania
    await Future.delayed(const Duration(milliseconds: 100));
    return <DashboardItem>[];
  }

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {
    // Mock implementation
  }

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {
    // Mock implementation
  }

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {
    // Mock implementation
  }
}
