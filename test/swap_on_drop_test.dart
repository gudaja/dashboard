import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// `Dashboard.swapOnDrop`: an item dropped exactly onto another item of the
/// same size exchanges places with it.
///
/// The grid of `pumpEditGrid`: 6 columns of 100 px slots in a 600x600 view.
void main() {
  testWidgets('T-SW-01 · 1x1 na 1x1: zamiana miejsc, oba zgłoszone',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 1, height: 1, startX: 2, startY: 1),
      ],
      swapOnDrop: true,
    );

    await dragInSteps(
        tester, tester.getRect(tile('a')).center, const Offset(2 * slot, slot),
        steps: 8);

    expect(layoutOf(controller, 'a'), '2,1 1x1');
    expect(layoutOf(controller, 'b'), '0,0 1x1');
    expect(delegate.updated, unorderedEquals(['a 2,1 1x1', 'b 0,0 1x1']));
    expect(
        tester.getRect(tile('a')).center, const Offset(2.5 * slot, 1.5 * slot));
    expect(
        tester.getRect(tile('b')).overlaps(tester.getRect(tile('a'))), isFalse);
    expect(tester.getRect(tile('b')).left, 0);
  });

  testWidgets('T-SW-02 · bez swapOnDrop ten sam ruch nie zamienia (kontrola)',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
      DashboardItem(identifier: 'b', width: 1, height: 1, startX: 2, startY: 1),
    ]);

    await dragInSteps(
        tester, tester.getRect(tile('a')).center, const Offset(2 * slot, slot),
        steps: 8);

    expect(layoutOf(controller, 'b'), '2,1 1x1');
    expect(layoutOf(controller, 'a'), isNot('2,1 1x1'));
  });

  testWidgets('T-SW-03 · 2x2 na 2x2 przez puste pole: zamiana',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 2, height: 2, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 2, height: 2, startX: 3, startY: 2),
      ],
      swapOnDrop: true,
    );

    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(3 * slot, 2 * slot),
        steps: 10);

    expect(layoutOf(controller, 'a'), '3,2 2x2');
    expect(layoutOf(controller, 'b'), '0,0 2x2');
  });

  testWidgets('T-SW-04 · inny rozmiar: bez zamiany, bez nakładania',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 2, height: 1, startX: 2, startY: 1),
      ],
      swapOnDrop: true,
    );

    await dragInSteps(
        tester, tester.getRect(tile('a')).center, const Offset(2 * slot, slot),
        steps: 8);

    expect(layoutOf(controller, 'b'), '2,1 2x1');
    expect(
        tester.getRect(tile('a')).overlaps(tester.getRect(tile('b'))), isFalse);
  });

  testWidgets(
      'T-SW-05 · upuszczenie przesunięte o slot względem drugiego: bez '
      'zamiany', (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 2, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 2, height: 1, startX: 2, startY: 2),
      ],
      swapOnDrop: true,
    );

    // Top-left on (3,2): inside b, but not b's top-left slot.
    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(3 * slot, 2 * slot),
        steps: 10);

    expect(layoutOf(controller, 'b'), '2,2 2x1');
    expect(
        tester.getRect(tile('a')).overlaps(tester.getRect(tile('b'))), isFalse);
  });

  testWidgets('T-SW-06 · scrollWhileEditing, mysz: zamiana też działa',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 1, height: 1, startX: 3, startY: 2),
      ],
      swapOnDrop: true,
      editModeSettings:
          EditModeSettings(resizeCursorSide: 20, scrollWhileEditing: true),
    );

    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(3 * slot, 2 * slot),
        steps: 10, kind: PointerDeviceKind.mouse);

    expect(layoutOf(controller, 'a'), '3,2 1x1');
    expect(layoutOf(controller, 'b'), '0,0 1x1');
    expect(delegate.updated, unorderedEquals(['a 3,2 1x1', 'b 0,0 1x1']));
  });

  testWidgets('T-SW-07 · zamiana pod sufitem i z dozwolonymi rozmiarami',
      (WidgetTester tester) async {
    final (controller, _) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 2, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 2, height: 1, startX: 4, startY: 2),
      ],
      swapOnDrop: true,
      maxRows: 3,
      isSizeAllowed: (w, h) => w == 2 && h == 1,
    );

    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(4 * slot, 2 * slot),
        steps: 10);

    expect(layoutOf(controller, 'a'), '4,2 2x1');
    expect(layoutOf(controller, 'b'), '0,0 2x1');
  });
}
