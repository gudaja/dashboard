import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// Moving an item by dragging it in edit mode.
///
/// Everything here goes through the public API of the package only.
void main() {
  testWidgets('T-M-01 · przeciągnięcie na wolne pole przenosi element',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, before.center, const Offset(3 * slot, 2 * slot),
        steps: 8);

    expect(layoutOf(controller, 'a'), '3,2 1x1');
    // Centred in slot (3, 2). Not `before.shift`: an item on the left/top
    // edge has no spacing on that side, one in the middle has it on all four.
    expect(
        tester.getRect(tile('a')).center, const Offset(3.5 * slot, 2.5 * slot));
    expect(before.center, const Offset(0.5 * slot - 2, 0.5 * slot - 2));
    expect(delegate.updated, ['a 3,2 1x1']);
  });

  testWidgets(
      'T-M-02 · szybki chwyt za środek przesuwa, a nie zmienia rozmiaru',
      (WidgetTester tester) async {
    // With the default DragStartBehavior.start the grab point was taken after
    // the touch slop: a fast first move from the centre of a small item landed
    // near its edge and the move became a resize (1x1 → 4x1).
    final (controller, _) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
    ]);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, before.center, const Offset(2 * slot, slot),
        steps: 2);

    expect(layoutOf(controller, 'a'), '2,1 1x1');
  });

  testWidgets('T-M-03 · upuszczenie na inny element: bez nakładania się',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
      DashboardItem(identifier: 'b', width: 1, height: 1, startX: 2, startY: 0),
    ]);

    await dragInSteps(
        tester, tester.getRect(tile('a')).center, const Offset(2 * slot, 0),
        steps: 8);

    expect(layoutOf(controller, 'b'), '2,0 1x1');
    final a = tester.getRect(tile('a'));
    final b = tester.getRect(tile('b'));
    expect(a.overlaps(b), isFalse, reason: 'a=$a b=$b');
  });

  testWidgets(
      'T-M-04 · upuszczenie na wyłączoną kolumnę kończy się w kolumnie '
      'włączonej', (WidgetTester tester) async {
    const disabled = 3;
    final (controller, _) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 1, startY: 0),
      ],
      slotCount: 7,
      virtualColumnsConfig: const VirtualColumnsConfig.visible(
          disabledColumns: [disabled], disabledColumnWidth: 0.05),
    );
    final start = tester.getRect(tile('a'));

    // Aim at the middle of the narrow disabled column.
    await dragInSteps(tester, start.center,
        Offset(2 * start.width - 20, 0), // two slots right, minus half of col 3
        steps: 8);

    final x = controller.allItems.single.layoutData.startX;
    expect(x, isNot(disabled));
    expect(x, inInclusiveRange(0, 6));
  });

  testWidgets('T-M-05 · poza trybem edycji przeciąganie nie rusza układu',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
    ]);
    controller.isEditing = false;
    await tester.pumpAndSettle();

    await dragInSteps(
        tester, tester.getRect(tile('a')).center, const Offset(2 * slot, 0));

    expect(layoutOf(controller, 'a'), '0,0 1x1');
    expect(delegate.updated, isEmpty);
  });
}
