import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// `Dashboard.onItemMoveUpdate` and `Dashboard.onItemDropOutside`: a host
/// follows a moved item and can take a drop released outside the grid.
///
/// The grid takes the top 300 px of the 600x600 view (6 columns, 100 px
/// slots, `maxRows` 3), so a pointer 350 px below a row-0 item is outside it.
void main() {
  final List<(String, Offset?)> moves = <(String, Offset?)>[];
  final List<(String, Offset)> drops = <(String, Offset)>[];

  setUp(() {
    moves.clear();
    drops.clear();
  });

  Future<(DashboardItemController<DashboardItem>, RecordingDelegate)> pump(
    WidgetTester tester, {
    required bool take,
    bool swapOnDrop = false,
    bool draggableOutside = false,
  }) =>
      pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'b', width: 1, height: 1, startX: 3, startY: 1),
        ],
        maxRows: 3,
        gridHeight: 300,
        swapOnDrop: swapOnDrop,
        editModeSettings: EditModeSettings(
            resizeCursorSide: 20, draggableOutside: draggableOutside),
        onItemMoveUpdate: (id, global) => moves.add((id, global)),
        onItemDropOutside: (id, global) {
          drops.add((id, global));
          return take;
        },
      );

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets(
        'T-DO-01 · ${kind.name}: upuszczenie poza siatką przyjęte przez '
        'hosta — element wraca na miejsce podjęcia, nic nie zgłoszone',
        (WidgetTester tester) async {
      final (controller, delegate) = await pump(tester, take: true);
      final from = tester.getRect(tile('a')).center;

      await dragInSteps(tester, from, const Offset(2 * slot, 3.5 * slot),
          steps: 8, kind: kind);

      expect(drops, hasLength(1));
      expect(drops.single.$1, 'a');
      expect(drops.single.$2.dy, greaterThan(300));
      expect(drops.single.$2, from + const Offset(2 * slot, 3.5 * slot));
      expect(layoutOf(controller, 'a'), '0,0 1x1');
      expect(delegate.updated, isEmpty);
      expect(tester.getRect(tile('a')).topLeft, Offset.zero);
      // Every pointer update of the move, the last one outside, then null.
      expect(moves.where((m) => m.$2 != null), hasLength(greaterThan(1)));
      expect(moves.every((m) => m.$1 == 'a'), isTrue);
      expect(moves.last.$2, isNull);
      expect(moves[moves.length - 2].$2!.dy, greaterThan(300));
    });
  }

  testWidgets(
      'T-DO-02 · host odmawia (false): zwykłe upuszczenie na krawędzi '
      'siatki', (WidgetTester tester) async {
    final (controller, delegate) = await pump(tester, take: false);

    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(2 * slot, 3.5 * slot),
        steps: 8);

    expect(drops, hasLength(1));
    expect(layoutOf(controller, 'a'), isNot('0,0 1x1'));
    expect(delegate.updated, hasLength(1));
  });

  testWidgets(
      'T-DO-03 · upuszczenie w siatce: bez onItemDropOutside, zwykły '
      'ruch', (WidgetTester tester) async {
    final (controller, delegate) = await pump(tester, take: true);

    await dragInSteps(
        tester, tester.getRect(tile('a')).center, const Offset(2 * slot, slot),
        steps: 8);

    expect(drops, isEmpty);
    expect(layoutOf(controller, 'a'), '2,1 1x1');
    expect(delegate.updated, ['a 2,1 1x1']);
    expect(moves.last.$2, isNull);
  });

  testWidgets(
      'T-DO-04 · zmiana rozmiaru wyciągnięta poza siatkę: żadna z dwóch '
      'funkcji', (WidgetTester tester) async {
    await pump(tester, take: true);
    final before = tester.getRect(tile('a'));

    await dragInSteps(tester, Offset(before.right - 5, before.center.dy),
        const Offset(slot, 4 * slot));

    expect(drops, isEmpty);
    expect(moves, isEmpty);
  });

  testWidgets(
      'T-DO-05 · swapOnDrop: przyjęte upuszczenie poza siatką niczego '
      'nie zamienia', (WidgetTester tester) async {
    final (controller, delegate) =
        await pump(tester, take: true, swapOnDrop: true);

    // Past b's slot (3,1) and on, out of the grid.
    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(3 * slot, 3.5 * slot),
        steps: 8);

    expect(layoutOf(controller, 'a'), '0,0 1x1');
    expect(layoutOf(controller, 'b'), '3,1 1x1');
    expect(delegate.updated, isEmpty);
  });

  testWidgets(
      'T-DO-06 · draggableOutside: true — element rysowany poza siatką też '
      'wraca', (WidgetTester tester) async {
    final (controller, delegate) =
        await pump(tester, take: true, draggableOutside: true);

    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(slot, 3.5 * slot),
        steps: 8);

    expect(drops, hasLength(1));
    expect(layoutOf(controller, 'a'), '0,0 1x1');
    expect(delegate.updated, isEmpty);
    expect(tester.getRect(tile('a')).topLeft, Offset.zero);
  });

  testWidgets('T-DO-07 · bez funkcji: zachowanie bez zmian (kontrola)',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
      ],
      maxRows: 3,
      gridHeight: 300,
      editModeSettings:
          EditModeSettings(resizeCursorSide: 20, draggableOutside: false),
    );

    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(2 * slot, 3.5 * slot),
        steps: 8);

    expect(layoutOf(controller, 'a'), isNot('0,0 1x1'));
    expect(delegate.updated, hasLength(1));
  });
}
