import 'dart:async';

import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two owner reports from the consumer's layout editor (2026-10-09):
///
/// * toggling edit mode on a scrolled grid threw the viewport back to the
///   top — the `Scrollable` was keyed by `isEditing`, so every toggle
///   remounted it with a fresh position at 0;
/// * a scattered layout could not be tidied — [DashboardItemController.compactToTop]
///   slides every item straight up.
void main() {
  const slotCount = 4;
  const slotHeight = 100.0;
  const surface = Size(400, 500);

  Widget grid(DashboardItemController<DashboardItem> controller) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: surface.width,
          height: surface.height,
          child: Dashboard<DashboardItem>(
            dashboardItemController: controller,
            slotCount: slotCount,
            slotHeight: slotHeight,
            // The consumer's setting: without it the grid compacts on mount
            // and there is nothing left for [compactToTop] to do.
            slideToTop: false,
            itemBuilder: (item) =>
                SizedBox.expand(key: ValueKey('tile_${item.identifier}')),
          ),
        ),
      ),
    );
  }

  Future<void> pumpGrid(
    WidgetTester tester,
    DashboardItemController<DashboardItem> controller,
  ) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(grid(controller));
    await tester.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  Map<String, List<int>> layouts(
          DashboardItemController<DashboardItem> controller) =>
      {
        for (final item in controller.allItems)
          item.identifier: [item.layoutData.startX, item.layoutData.startY],
      };

  group('edit-mode toggle keeps the scroll offset', () {
    testWidgets('T-CT-01 · locking and unlocking keeps pixels',
        (tester) async {
      final controller = DashboardItemController<DashboardItem>(items: [
        for (var i = 0; i < 20; i++)
          DashboardItem(
              identifier: 'i$i', width: 2, height: 2, startX: 0, startY: i * 2),
      ]);
      await pumpGrid(tester, controller);

      // Scroll while NOT editing — the only state in which the grid scrolls.
      await tester.drag(find.byType(Scrollable), const Offset(0, -900));
      await tester.pumpAndSettle();
      final scrolled = position(tester).pixels;
      expect(scrolled, greaterThan(500));

      controller.isEditing = true;
      await tester.pumpAndSettle();
      expect(position(tester).pixels, scrolled,
          reason: 'entering edit mode must not reset the viewport');

      controller.isEditing = false;
      await tester.pumpAndSettle();
      expect(position(tester).pixels, scrolled,
          reason: 'leaving edit mode must not reset the viewport');
    });

    testWidgets('T-CT-02 · physics still follow the mode', (tester) async {
      final controller = DashboardItemController<DashboardItem>(items: [
        for (var i = 0; i < 20; i++)
          DashboardItem(
              identifier: 'i$i', width: 2, height: 2, startX: 0, startY: i * 2),
      ]);
      await pumpGrid(tester, controller);

      controller.isEditing = true;
      await tester.pumpAndSettle();
      // A drag on the free right half (no item there) must not scroll.
      await tester.dragFrom(const Offset(350, 400), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(position(tester).pixels, 0,
          reason: 'edit mode pins the viewport');

      controller.isEditing = false;
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(350, 400), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(position(tester).pixels, greaterThan(0),
          reason: 'out of edit mode the grid scrolls again');
    });
  });

  group('compactToTop', () {
    testWidgets('T-CT-03 · items slide up in their own column',
        (tester) async {
      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(identifier: 'a', width: 2, height: 1, startX: 0, startY: 3),
        DashboardItem(identifier: 'b', width: 2, height: 2, startX: 2, startY: 6),
        // Stands under `a` in the same columns: must stop right below it.
        DashboardItem(identifier: 'c', width: 1, height: 1, startX: 1, startY: 9),
        // Already at the top — not reported as moved.
        DashboardItem(identifier: 'd', width: 1, height: 1, startX: 3, startY: 0),
      ]);
      await pumpGrid(tester, controller);

      final moved = controller.compactToTop();
      await tester.pumpAndSettle();

      expect(moved.toSet(), {'a', 'b', 'c'});
      expect(layouts(controller), {
        'a': [0, 0],
        'b': [2, 1], // `d` blocks column 3 on row 0
        'c': [1, 1],
        'd': [3, 0],
      });
      // And the grid draws them there.
      expect(tester.getTopLeft(find.byKey(const ValueKey('tile_a'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const ValueKey('tile_c'))).dy));
    });

    testWidgets('T-CT-04 · an item never jumps over the one above it',
        (tester) async {
      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(identifier: 'top', width: 1, height: 1, startX: 0, startY: 2),
        DashboardItem(
            identifier: 'wide', width: 4, height: 1, startX: 0, startY: 4),
        DashboardItem(
            identifier: 'under', width: 1, height: 1, startX: 3, startY: 7),
      ]);
      await pumpGrid(tester, controller);

      controller.compactToTop();
      await tester.pumpAndSettle();

      expect(layouts(controller), {
        'top': [0, 0],
        'wide': [0, 1],
        // Column 3 is free on row 0, but `wide` stands in the way.
        'under': [3, 2],
      });
    });

    testWidgets('T-CT-05 · the storage delegate hears ONE update of the moved',
        (tester) async {
      final storage = _RecordingStorage([
        DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
        DashboardItem(identifier: 'b', width: 1, height: 1, startX: 1, startY: 5),
      ]);
      final controller = DashboardItemController<DashboardItem>.withDelegate(
          itemStorageDelegate: storage);
      await pumpGrid(tester, controller);
      storage.updates.clear();

      expect(controller.compactToTop(), ['b']);
      expect(storage.updates, hasLength(1));
      expect(storage.updates.single.map((i) => i.identifier), ['b']);
      expect(storage.updates.single.single.layoutData.startY, 0);

      // A compact layout moves nothing and writes nothing.
      expect(controller.compactToTop(), isEmpty);
      expect(storage.updates, hasLength(1));
    });

    testWidgets('T-CT-06 · a scroll offset past the new end is clamped',
        (tester) async {
      final controller = DashboardItemController<DashboardItem>(items: [
        for (var i = 0; i < 6; i++)
          DashboardItem(
              identifier: 'i$i', width: 1, height: 1, startX: i % 4, startY: i * 3),
      ]);
      await pumpGrid(tester, controller);
      await tester.drag(find.byType(Scrollable), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(position(tester).pixels, greaterThan(0));

      controller.compactToTop();
      await tester.pumpAndSettle();

      expect(position(tester).pixels,
          lessThanOrEqualTo(position(tester).maxScrollExtent));
      expect(tester.takeException(), isNull);
    });
  });
}

class _RecordingStorage extends DashboardItemStorageDelegate<DashboardItem> {
  _RecordingStorage(this._items);

  final List<DashboardItem> _items;
  final List<List<DashboardItem>> updates = [];

  @override
  bool get cacheItems => true;

  @override
  bool get layoutsBySlotCount => false;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) => _items;

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {
    updates.add(List.of(items));
  }
}
