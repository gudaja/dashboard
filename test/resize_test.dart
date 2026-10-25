import 'package:dashboard/dashboard.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// Resizing an item by dragging its edges in edit mode.
///
/// Everything here goes through the public API of the package only. Each test
/// checks the layout the controller holds, the size on screen and the write
/// that reaches the storage delegate.
void main() {
  testWidgets('T-R-01 · prawa krawędź o jeden slot: 2x1 → 3x1',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.right - 5, before.center.dy),
        const Offset(slot, 0));

    expect(layoutOf(controller, 'a'), '2,0 3x1');
    expect(tester.getRect(tile('a')).left, before.left);
    expect(tester.getRect(tile('a')).width, before.width + slot);
    expect(delegate.updated, ['a 2,0 3x1']);
  });

  testWidgets('T-R-02 · lewa krawędź o jeden slot: start w lewo, 3x1',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.left + 5, before.center.dy),
        const Offset(-slot, 0));

    expect(layoutOf(controller, 'a'), '1,0 3x1');
    expect(tester.getRect(tile('a')).right, before.right);
    expect(delegate.updated, ['a 1,0 3x1']);
  });

  testWidgets('T-R-03 · dolna krawędź o jeden slot: 2x1 → 2x2',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.center.dx, before.bottom - 5),
        const Offset(0, slot));

    expect(layoutOf(controller, 'a'), '2,0 2x2');
    expect(tester.getRect(tile('a')).height, before.height + slot);
    expect(delegate.updated, ['a 2,0 2x2']);
  });

  testWidgets('T-R-04 · zmniejszanie zatrzymuje się na minWidth',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(tester, [
      DashboardItem(
          identifier: 'a',
          width: 3,
          height: 1,
          startX: 0,
          startY: 0,
          minWidth: 2),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.right - 5, before.center.dy),
        const Offset(-2.5 * slot, 0));

    expect(layoutOf(controller, 'a'), '0,0 2x1');
  });

  testWidgets('T-R-05 · powiększanie zatrzymuje się na maxWidth',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(tester, [
      DashboardItem(
          identifier: 'a',
          width: 2,
          height: 1,
          startX: 0,
          startY: 0,
          maxWidth: 3),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.right - 5, before.center.dy),
        const Offset(3 * slot, 0));

    expect(layoutOf(controller, 'a'), '0,0 3x1');
  });

  testWidgets(
      'T-R-06 · szybki ruch palcem od krawędzi (jeden krok > próg dotyku) '
      'nadal zmienia rozmiar', (WidgetTester tester) async {
    // With the default DragStartBehavior.start, `onPanStart` reported the
    // position AFTER the 18 px touch slop: a grab 5 px inside the right edge,
    // pulled outwards, started outside the item and nothing happened.
    final (controller, _) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.right - 5, before.center.dy),
        const Offset(slot, 0),
        steps: 1);

    expect(layoutOf(controller, 'a'), '2,0 3x1');
  });

  testWidgets('T-R-07 · to samo myszą', (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.right - 5, before.center.dy),
        const Offset(slot, 0),
        kind: PointerDeviceKind.mouse);

    expect(layoutOf(controller, 'a'), '2,0 3x1');
  });

  testWidgets(
      'T-R-08 · rozciąganie na wyłączoną kolumnę jest blokowane, bez zapisu',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 2, height: 1, startX: 1, startY: 0),
      ],
      slotCount: 7,
      virtualColumnsConfig: const VirtualColumnsConfig.visible(
          disabledColumns: [3], disabledColumnWidth: 0.05),
    );
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.right - 5, before.center.dy),
        const Offset(2.5 * slot, 0),
        steps: 8);

    expect(layoutOf(controller, 'a'), '1,0 2x1');
    expect(tester.getRect(tile('a')), before);
    expect(delegate.updated, isEmpty);
  });
}
