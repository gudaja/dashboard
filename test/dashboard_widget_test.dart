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

  group('Dashboard Scaling Tests', () {
    testWidgets('should handle slotCount changes (horizontal scaling)',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(
            identifier: 'item1', width: 2, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'item2', width: 1, height: 1, startX: 2, startY: 0),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Testujemy różne wartości slotCount
      for (int slotCount in [4, 6, 8, 10]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  key: Key('${item.identifier}_$slotCount'),
                  color: Colors.blue,
                  child: Text('${item.identifier} - $slotCount slots'),
                ),
                dashboardItemController: controller,
                slotCount: slotCount,
              ),
            ),
          ),
        );

        expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
        expect(find.byKey(Key('item1_$slotCount')), findsOneWidget);
        expect(find.byKey(Key('item2_$slotCount')), findsOneWidget);
      }
    });

    testWidgets('should handle slotHeight scaling',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 1, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Testujemy różne wysokości slotów
      for (double slotHeight in [50.0, 100.0, 150.0, 200.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  key: Key('item1_height_${slotHeight.toInt()}'),
                  color: Colors.red,
                  child: Text('Height: ${slotHeight.toInt()}'),
                ),
                dashboardItemController: controller,
                slotHeight: slotHeight,
              ),
            ),
          ),
        );

        expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
        expect(find.byKey(Key('item1_height_${slotHeight.toInt()}')),
            findsOneWidget);
      }
    });

    testWidgets('should handle slotAspectRatio scaling',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 2, height: 1),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Testujemy różne aspect ratio
      for (double aspectRatio in [0.5, 1.0, 1.5, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  key: Key('item1_aspect_${(aspectRatio * 10).toInt()}'),
                  color: Colors.green,
                  child: Text('Aspect: $aspectRatio'),
                ),
                dashboardItemController: controller,
                slotAspectRatio: aspectRatio,
              ),
            ),
          ),
        );

        expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
        expect(find.byKey(Key('item1_aspect_${(aspectRatio * 10).toInt()}')),
            findsOneWidget);
      }
    });

    testWidgets('should handle different screen sizes (responsive scaling)',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'item1', width: 3, height: 2),
        DashboardItem(identifier: 'item2', width: 2, height: 1),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Testujemy różne rozmiary ekranu
      final screenSizes = [
        const Size(400, 600), // Mobile portrait
        const Size(600, 400), // Mobile landscape
        const Size(768, 1024), // Tablet portrait
        const Size(1024, 768), // Tablet landscape
        const Size(1920, 1080), // Desktop
      ];

      for (Size screenSize in screenSizes) {
        await tester.binding.setSurfaceSize(screenSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  key: Key(
                      '${item.identifier}_${screenSize.width.toInt()}x${screenSize.height.toInt()}'),
                  color: Colors.purple,
                  child: Text(
                      '${item.identifier} ${screenSize.width.toInt()}x${screenSize.height.toInt()}'),
                ),
                dashboardItemController: controller,
                slotCount: 6,
              ),
            ),
          ),
        );

        expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
        expect(
            find.byKey(Key(
                'item1_${screenSize.width.toInt()}x${screenSize.height.toInt()}')),
            findsOneWidget);
        expect(
            find.byKey(Key(
                'item2_${screenSize.width.toInt()}x${screenSize.height.toInt()}')),
            findsOneWidget);
      }

      // Przywróć domyślny rozmiar
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('should handle scaling with custom spacing',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'scaled_item', width: 2, height: 2),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Testujemy skalowanie z różnymi spacingami
      final spacingConfigs = [
        {'horizontal': 4.0, 'vertical': 4.0},
        {'horizontal': 8.0, 'vertical': 8.0},
        {'horizontal': 16.0, 'vertical': 16.0},
        {'horizontal': 32.0, 'vertical': 32.0},
      ];

      for (var config in spacingConfigs) {
        final h = config['horizontal']!;
        final v = config['vertical']!;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  key: Key('scaled_item_${h.toInt()}_${v.toInt()}'),
                  color: Colors.orange,
                  child: Text('Spacing: ${h.toInt()}/${v.toInt()}'),
                ),
                dashboardItemController: controller,
                horizontalSpace: h,
                verticalSpace: v,
                slotCount: 4,
                slotHeight: 100,
              ),
            ),
          ),
        );

        expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
        expect(find.byKey(Key('scaled_item_${h.toInt()}_${v.toInt()}')),
            findsOneWidget);
      }
    });

    testWidgets('should handle scaling with custom padding',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(identifier: 'padded_item', width: 1, height: 1),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Testujemy różne padding values
      final paddingValues = [
        EdgeInsets.zero,
        const EdgeInsets.all(8.0),
        const EdgeInsets.all(16.0),
        const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        const EdgeInsets.only(left: 30.0, top: 15.0, right: 30.0, bottom: 15.0),
      ];

      for (int i = 0; i < paddingValues.length; i++) {
        final padding = paddingValues[i];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  key: Key('padded_item_$i'),
                  color: Colors.cyan,
                  child: Text('Padding $i'),
                ),
                dashboardItemController: controller,
                padding: padding,
                slotCount: 3,
                slotHeight: 80,
              ),
            ),
          ),
        );

        expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
        expect(find.byKey(Key('padded_item_$i')), findsOneWidget);
      }
    });

    testWidgets('should handle combined scaling parameters',
        (WidgetTester tester) async {
      final items = [
        DashboardItem(
            identifier: 'combo1', width: 2, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'combo2', width: 1, height: 2, startX: 2, startY: 0),
      ];

      final controller = DashboardItemController<DashboardItem>(items: items);

      // Test kombinacji różnych parametrów skalowania
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                key: Key('${item.identifier}_combined'),
                decoration: BoxDecoration(
                  color: item.identifier == 'combo1' ? Colors.red : Colors.blue,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Center(
                  child: Text(
                    item.identifier,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              dashboardItemController: controller,
              slotCount: 8,
              slotAspectRatio: 1.2,
              horizontalSpace: 12.0,
              verticalSpace: 10.0,
              padding: const EdgeInsets.all(16.0),
            ),
          ),
        ),
      );

      expect(find.byType(Dashboard<DashboardItem>), findsOneWidget);
      expect(find.byKey(const Key('combo1_combined')), findsOneWidget);
      expect(find.byKey(const Key('combo2_combined')), findsOneWidget);

      // Sprawdź że elementy są poprawnie wyrenderowane
      expect(find.text('combo1'), findsOneWidget);
      expect(find.text('combo2'), findsOneWidget);
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
