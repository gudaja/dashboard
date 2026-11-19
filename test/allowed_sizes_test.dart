import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// `Dashboard.isSizeAllowed`: only a fixed set of `width x height` sizes.
///
/// The grid of `pumpEditGrid`: 6 columns of 100 px slots in a 600x600 view.
void main() {
  bool Function(int, int) only(Set<String> sizes) =>
      (w, h) => sizes.contains('${w}x$h');

  Offset bottomOf(Rect r) => Offset(r.center.dx, r.bottom - 5);
  Offset rightOf(Rect r) => Offset(r.right - 5, r.center.dy);

  group('zmiana rozmiaru', () {
    testWidgets(
        'T-AS-01 · {1x1, 2x1, 2x2}: ciągnięcie 1x1 w dół nigdy nie daje 1x2',
        (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 2, startY: 1),
        ],
        isSizeAllowed: only({'1x1', '2x1', '2x2'}),
      );
      final before = tester.getRect(tile('a'));
      final gesture = await tester.startGesture(bottomOf(before),
          kind: PointerDeviceKind.mouse);
      await tester.pump();

      // Every step of the way, not only at the drop.
      for (var i = 0; i < 6; i++) {
        await moveInSteps(tester, gesture, const Offset(0, 0.5 * slot),
            steps: 2);
        expect(layoutOf(controller, 'a'), '2,1 1x1', reason: 'step $i');
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'a'), '2,1 1x1');
      expect(tester.getRect(tile('a')), before);
      expect(delegate.updated, isEmpty);
    });

    testWidgets('T-AS-02 · bez isSizeAllowed ten sam ruch daje 1x2 (kontrola)',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 2, startY: 1),
      ]);

      await dragInSteps(
          tester, bottomOf(tester.getRect(tile('a'))), const Offset(0, slot),
          kind: PointerDeviceKind.mouse);

      expect(layoutOf(controller, 'a'), '2,1 1x2');
    });

    testWidgets('T-AS-03 · {1x1, 2x1, 2x2}: w prawo 2x1, potem w dół 2x2',
        (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 2, startY: 1),
        ],
        isSizeAllowed: only({'1x1', '2x1', '2x2'}),
      );

      await dragInSteps(
          tester, rightOf(tester.getRect(tile('a'))), const Offset(slot, 0),
          kind: PointerDeviceKind.mouse);
      expect(layoutOf(controller, 'a'), '2,1 2x1');

      await dragInSteps(tester, bottomOf(tester.getRect(tile('a'))),
          const Offset(0, 2 * slot),
          steps: 8, kind: PointerDeviceKind.mouse);
      expect(layoutOf(controller, 'a'), '2,1 2x2');
      expect(delegate.updated, ['a 2,1 2x1', 'a 2,1 2x2']);
    });

    testWidgets(
        'T-AS-04 · {1x1, 3x1}: 2x1 jest pomijany — +1 slot nic, +2 sloty 3x1',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 1, startY: 1),
        ],
        isSizeAllowed: only({'1x1', '3x1'}),
      );
      final gesture = await tester.startGesture(
          rightOf(tester.getRect(tile('a'))),
          kind: PointerDeviceKind.mouse);
      await tester.pump();

      await moveInSteps(tester, gesture, const Offset(slot, 0), steps: 5);
      expect(layoutOf(controller, 'a'), '1,1 1x1',
          reason: 'one slot out: 2x1 is refused');

      await moveInSteps(tester, gesture, const Offset(slot, 0), steps: 5);
      expect(layoutOf(controller, 'a'), '1,1 3x1',
          reason: 'past the trigger of 3x1');
      await gesture.up();
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'a'), '1,1 3x1');
    });

    testWidgets('T-AS-05 · {1x1, 3x1}: zmniejszanie też przeskakuje 2x1',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 3, height: 1, startX: 1, startY: 1),
        ],
        isSizeAllowed: only({'1x1', '3x1'}),
      );

      await dragInSteps(
          tester, rightOf(tester.getRect(tile('a'))), const Offset(-slot, 0),
          kind: PointerDeviceKind.mouse);
      expect(layoutOf(controller, 'a'), '1,1 3x1');

      await dragInSteps(tester, rightOf(tester.getRect(tile('a'))),
          const Offset(-2 * slot, 0),
          steps: 8, kind: PointerDeviceKind.mouse);
      expect(layoutOf(controller, 'a'), '1,1 1x1');
    });

    testWidgets(
        'T-AS-06 · {1x1, 3x1}: przeskok zablokowany przez sąsiada na krawędzi '
        'jest wycofany w całości', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 3, startY: 1),
          DashboardItem(
              identifier: 'b', width: 1, height: 1, startX: 5, startY: 1),
        ],
        isSizeAllowed: only({'1x1', '3x1'}),
      );

      // 2x1 would be free, 3x1 needs b's column and b cannot move or shrink.
      await dragInSteps(
          tester, rightOf(tester.getRect(tile('a'))), const Offset(2 * slot, 0),
          steps: 8, kind: PointerDeviceKind.mouse);

      expect(layoutOf(controller, 'a'), '3,1 1x1');
      expect(layoutOf(controller, 'b'), '5,1 1x1');
    });

    testWidgets(
        'T-AS-07 · popychany sąsiad nie jest zmniejszany do niedozwolonego '
        'rozmiaru', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 4, height: 1, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'b', width: 2, height: 1, startX: 4, startY: 0),
        ],
        isSizeAllowed: only({'2x1', '4x1', '5x1'}),
      );

      await dragInSteps(
          tester, rightOf(tester.getRect(tile('a'))), const Offset(slot, 0),
          kind: PointerDeviceKind.mouse);

      expect(layoutOf(controller, 'a'), '0,0 4x1');
      expect(layoutOf(controller, 'b'), '4,0 2x1');
    });

    testWidgets('T-AS-08 · bez isSizeAllowed sąsiad się zmniejsza (kontrola)',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, [
        DashboardItem(
            identifier: 'a', width: 4, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 2, height: 1, startX: 4, startY: 0),
      ]);

      await dragInSteps(
          tester, rightOf(tester.getRect(tile('a'))), const Offset(slot, 0),
          kind: PointerDeviceKind.mouse);

      expect(layoutOf(controller, 'a'), '0,0 5x1');
      expect(layoutOf(controller, 'b'), '5,0 1x1');
    });

    testWidgets(
        'T-AS-09 · domyślne przeciąganie bez isSizeAllowed: nadal krok co slot',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 1, startY: 1),
      ]);

      await dragInSteps(
          tester, rightOf(tester.getRect(tile('a'))), const Offset(2 * slot, 0),
          steps: 8, kind: PointerDeviceKind.mouse);

      expect(layoutOf(controller, 'a'), '1,1 3x1');
    });
  });

  group('shrinkOnMove i add', () {
    // a 2x2 dropped at (3,0) overlaps b at (4,1): shrinkOnMove would make it
    // 2x1 or 1x2 there.
    List<DashboardItem> items() => [
          DashboardItem(
              identifier: 'a', width: 2, height: 2, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'b', width: 1, height: 1, startX: 4, startY: 1),
        ];

    testWidgets('T-AS-10 · shrinkOnMove bez isSizeAllowed zmniejsza (kontrola)',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, items(),
          editModeSettings:
              EditModeSettings(resizeCursorSide: 20, shrinkOnMove: true));

      await dragInSteps(
          tester, tester.getRect(tile('a')).center, const Offset(3 * slot, 0),
          steps: 8);

      expect(layoutOf(controller, 'a'), isNot(endsWith('2x2')));
    });

    testWidgets(
        'T-AS-11 · shrinkOnMove nigdy nie daje niedozwolonego rozmiaru: '
        'ruch w to miejsce jest odmówiony', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, items(),
          isSizeAllowed: only({'2x2'}),
          editModeSettings:
              EditModeSettings(resizeCursorSide: 20, shrinkOnMove: true));

      await dragInSteps(
          tester, tester.getRect(tile('a')).center, const Offset(3 * slot, 0),
          steps: 8);

      final a = layoutOf(controller, 'a');
      expect(a, endsWith('2x2'));
      expect(a, isNot('3,0 2x2'));
      expect(tester.getRect(tile('a')).overlaps(tester.getRect(tile('b'))),
          isFalse);
    });

    testWidgets('T-AS-12 · shrinkOnMove wybiera największy dozwolony rozmiar',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, items(),
          isSizeAllowed: only({'1x1', '2x2'}),
          editModeSettings:
              EditModeSettings(resizeCursorSide: 20, shrinkOnMove: true));

      await dragInSteps(
          tester, tester.getRect(tile('a')).center, const Offset(3 * slot, 0),
          steps: 8);

      // 2x1 and 1x2 would fit at (3,0); both are refused, 1x1 is not.
      expect(layoutOf(controller, 'a'), '3,0 1x1');
    });

    testWidgets('T-AS-13 · add z dopasowaniem nie daje niedozwolonego rozmiaru',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 4, height: 1, startX: 0, startY: 0),
        ],
        isSizeAllowed: only({'1x1', '3x1', '4x1'}),
        shrinkToPlace: true,
      );

      // Asked for 3x1 at (3,0): it fits only shrunk, at (4,0); 2x1 is
      // refused, so 1x1.
      controller.add(
          DashboardItem(
              identifier: 'b', width: 3, height: 1, startX: 3, startY: 0),
          mountToTop: false);
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'b'), '4,0 1x1');
    });

    testWidgets('T-AS-14 · ten sam add bez isSizeAllowed daje 2x1 (kontrola)',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 4, height: 1, startX: 0, startY: 0),
        ],
        shrinkToPlace: true,
      );

      controller.add(
          DashboardItem(
              identifier: 'b', width: 3, height: 1, startX: 3, startY: 0),
          mountToTop: false);
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'b'), '4,0 2x1');
    });

    testWidgets(
        'T-AS-15 · własny, niedozwolony rozmiar elementu nie jest odrzucany '
        'przy wczytaniu ani przy ruchu', (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 2, startX: 0, startY: 0),
        ],
        isSizeAllowed: only({'1x1'}),
      );
      expect(layoutOf(controller, 'a'), '0,0 1x2');
      expect(delegate.updated, isEmpty);
      expect(
          controller.canPlace(
              ItemLayout(startX: 0, startY: 0, width: 1, height: 2),
              ignoreId: 'a'),
          isFalse,
          reason: 'canPlace checks every size');

      await dragInSteps(
          tester, tester.getRect(tile('a')).center, const Offset(2 * slot, 0),
          steps: 8);
      expect(layoutOf(controller, 'a'), '2,0 1x2');
    });
  });
}
