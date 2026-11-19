import 'dart:async';

import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// A VALID stored layout — no overlaps, inside the grid — is mounted exactly
/// as stored with `slideToTop: false` and `shrinkToPlace: false`, and the
/// load reports no change.
///
/// What a wall-panel editor relies on: the positions are the central's, and
/// a write-back on load would be a write nobody asked for.
void main() {
  /// A 6 x 4 board with gaps, listed bottom-up so the order of the list is
  /// not the reading order.
  List<DashboardItem> board() => [
        DashboardItem(
            identifier: 'd', width: 4, height: 2, startX: 0, startY: 2),
        DashboardItem(
            identifier: 'c', width: 1, height: 1, startX: 5, startY: 3),
        DashboardItem(
            identifier: 'b', width: 3, height: 2, startX: 3, startY: 0),
        DashboardItem(
            identifier: 'a', width: 2, height: 1, startX: 0, startY: 1),
      ];

  const expected = {
    'a': '0,1 2x1',
    'b': '3,0 3x2',
    'c': '5,3 1x1',
    'd': '0,2 4x2',
  };

  void expectExact(DashboardItemController<DashboardItem> controller) {
    for (final MapEntry(key: id, value: layout) in expected.entries) {
      expect(layoutOf(controller, id), layout, reason: id);
    }
  }

  for (final maxRows in [null, 4]) {
    testWidgets(
        'T-EM-01 · wczytanie przez delegata: dokładnie zapisane miejsca, bez '
        'onItemsUpdated (maxRows: $maxRows)', (WidgetTester tester) async {
      final (controller, delegate) =
          await pumpEditGrid(tester, board(), maxRows: maxRows);

      expectExact(controller);
      expect(delegate.updated, isEmpty);
      // On screen too: b spans columns 3..5 and rows 0..1.
      final b = tester.getRect(tile('b'));
      expect(b.left, closeTo(3 * slot, 4));
      expect(b.right, closeTo(6 * slot, 4));
      expect(b.bottom, closeTo(2 * slot, 4));
    });

    testWidgets(
        'T-EM-02 · addAll(mountToTop: false): dokładnie zapisane miejsca, bez '
        'onItemsUpdated (maxRows: $maxRows)', (WidgetTester tester) async {
      final (controller, delegate) =
          await pumpEditGrid(tester, [], maxRows: maxRows, editing: false);

      controller.addAll(board(), mountToTop: false);
      await tester.pumpAndSettle();

      expectExact(controller);
      expect(delegate.updated, isEmpty);
      expect(delegate.added, [
        ['d', 'c', 'b', 'a']
      ]);
    });
  }

  testWidgets(
      'T-EM-03 · wczytanie asynchroniczne (Future) też jest dokładne i bez '
      'zapisu', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final delegate = _AsyncDelegate(board());
    final controller = DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: delegate);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dashboard<DashboardItem>(
          dashboardItemController: controller,
          slotCount: 6,
          slotHeight: slot,
          slideToTop: false,
          shrinkToPlace: false,
          maxRows: 4,
          itemBuilder: (item) => ColoredBox(
              key: ValueKey('tile_${item.identifier}'), color: Colors.red),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expectExact(controller);
    expect(delegate.updated, isEmpty);
  });

  testWidgets(
      'T-EM-04 · add(mountToTop: false) pojedynczo: dokładne miejsce, także '
      'gdy nad nim jest wolne', (WidgetTester tester) async {
    final (controller, delegate) =
        await pumpEditGrid(tester, [], maxRows: 4, editing: false);

    controller.add(
        DashboardItem(
            identifier: 'c', width: 1, height: 1, startX: 5, startY: 3),
        mountToTop: false);
    await tester.pumpAndSettle();

    expect(layoutOf(controller, 'c'), '5,3 1x1');
    expect(delegate.updated, isEmpty);
  });
}

class _AsyncDelegate extends RecordingDelegate {
  _AsyncDelegate(super.source);

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) =>
      Future<List<DashboardItem>>.delayed(
          const Duration(milliseconds: 10), () => source);
}
