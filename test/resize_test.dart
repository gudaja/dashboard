import 'package:dashboard/dashboard.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  // With the default resizeHysteresis of 0.05 a step is taken once an edge is
  // more than 55% of a slot past its grid line, in either direction.
  group('T-R-09 · próg w połowie slotu z histerezą', () {
    for (final (edge, axis) in [
      ('right', const Offset(1, 0)),
      ('left', const Offset(-1, 0)),
      ('bottom', const Offset(0, 1)),
      ('top', const Offset(0, -1)),
    ]) {
      for (final (pull, expected) in [
        (52.0, 2), // grow: not yet
        (58.0, 3), // grow
        (-52.0, 2), // shrink: not yet
        (-58.0, 1), // shrink
      ]) {
        testWidgets('$edge o ${pull.round()}% slotu → $expected',
            (WidgetTester tester) async {
          final (controller, _) = await pumpEditGrid(tester, [
            DashboardItem(
                identifier: 'a', width: 2, height: 2, startX: 2, startY: 2),
          ]);

          await dragInSteps(
              tester, _grab(tester.getRect(tile('a')), edge), axis * pull,
              steps: 10, kind: PointerDeviceKind.mouse);

          final l = controller.allItems.single.layoutData;
          expect(axis.dx != 0 ? l.width : l.height, expected);
        });
      }
    }
  });

  // Grown at +70; the step back is only taken below +45 (55% back into the
  // new last slot).
  for (final (back, expected) in [(-20.0, '2,2 3x2'), (-40.0, '2,2 2x2')]) {
    testWidgets(
        'T-R-10 · histereza: urośnij przy +70, puść przy '
        '+${70 + back.round()} → $expected', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, [
        DashboardItem(
            identifier: 'a', width: 2, height: 2, startX: 2, startY: 2),
      ]);
      final gesture = await tester.startGesture(
          _grab(tester.getRect(tile('a')), 'right'),
          kind: PointerDeviceKind.mouse);
      await tester.pump();

      await moveInSteps(tester, gesture, const Offset(70, 0), steps: 7);
      await moveInSteps(tester, gesture, Offset(back, 0), steps: 4);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'a'), expected);
    });
  }

  testWidgets('T-R-11 · resizeHysteresis: 0 przełącza dokładnie w połowie',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 2, height: 2, startX: 2, startY: 2),
      ],
      editModeSettings:
          EditModeSettings(resizeCursorSide: 20, resizeHysteresis: 0),
    );

    await dragInSteps(
        tester, _grab(tester.getRect(tile('a')), 'right'), const Offset(55, 0),
        steps: 11, kind: PointerDeviceKind.mouse);

    expect(layoutOf(controller, 'a'), '2,2 3x2');
  });

  testWidgets(
      'T-R-12 · w trakcie przeciągania kafelek idzie za kursorem także '
      'przed krokiem', (WidgetTester tester) async {
    await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 2, height: 2, startX: 2, startY: 2),
    ]);
    final before = tester.getRect(tile('a'));
    final gesture = await tester.startGesture(_grab(before, 'right'),
        kind: PointerDeviceKind.mouse);
    await tester.pump();

    await moveInSteps(tester, gesture, const Offset(40, 0), steps: 4);
    expect(tester.getRect(tile('a')).width, before.width + 40,
        reason: 'drawn 40 px wider before the 55% step');

    await moveInSteps(tester, gesture, const Offset(-80, 0), steps: 4);
    expect(tester.getRect(tile('a')).width, before.width - 40,
        reason: 'and 40 px narrower before the step back');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}

/// A point 5 px inside [edge] of [rect], halfway along it.
Offset _grab(Rect rect, String edge) => switch (edge) {
      'right' => Offset(rect.right - 5, rect.center.dy),
      'left' => Offset(rect.left + 5, rect.center.dy),
      'bottom' => Offset(rect.center.dx, rect.bottom - 5),
      _ => Offset(rect.center.dx, rect.top + 5),
    };
