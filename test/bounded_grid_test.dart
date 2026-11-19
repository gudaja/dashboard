import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// `Dashboard.maxRows` — a fixed board of `slotCount` x `maxRows` slots —
/// and `DashboardItemController.canPlace`.
///
/// The grid of `pumpEditGrid`: 6 columns of 100 px slots in a 600x600 view.
void main() {
  /// Every item of [controller] ends at or above row [maxRows].
  void expectUnderCeiling(
      DashboardItemController<DashboardItem> controller, int maxRows) {
    for (final item in controller.allItems) {
      final l = item.layoutData;
      expect(l.startY + l.height, lessThanOrEqualTo(maxRows),
          reason: '${item.identifier}: $l');
    }
  }

  group('ruch', () {
    testWidgets(
        'T-BG-01 · przeciągnięcie poniżej sufitu kończy się na ostatnim '
        'wierszu', (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
        ],
        maxRows: 3,
      );

      await dragInSteps(tester, tester.getRect(tile('a')).center,
          const Offset(slot, 5 * slot),
          steps: 10);

      expect(layoutOf(controller, 'a'), '1,2 1x1');
      expect(delegate.updated, ['a 1,2 1x1']);
    });

    testWidgets('T-BG-02 · wysoki element: ostatni wiersz, w którym się mieści',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 2, startX: 0, startY: 0),
        ],
        maxRows: 3,
      );

      await dragInSteps(
          tester, tester.getRect(tile('a')).center, const Offset(0, 3 * slot),
          steps: 10);

      expect(layoutOf(controller, 'a'), '0,1 1x2');
      expectUnderCeiling(controller, 3);
    });

    testWidgets(
        'T-BG-03 · bez sufitu ten sam ruch schodzi niżej (kontrola T-BG-01)',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
      ]);

      await dragInSteps(tester, tester.getRect(tile('a')).center,
          const Offset(slot, 5 * slot),
          steps: 10);

      expect(layoutOf(controller, 'a'), '1,5 1x1');
    });

    testWidgets('T-BG-04 · shrinkOnMove nie wypycha elementu za sufit',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 2, height: 2, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'b', width: 6, height: 1, startX: 0, startY: 2),
        ],
        maxRows: 3,
        editModeSettings:
            EditModeSettings(resizeCursorSide: 20, shrinkOnMove: true),
      );

      await dragInSteps(tester, tester.getRect(tile('a')).center,
          const Offset(2 * slot, 3 * slot),
          steps: 10);

      expectUnderCeiling(controller, 3);
      expect(layoutOf(controller, 'b'), '0,2 6x1');
    });
  });

  group('zmiana rozmiaru', () {
    testWidgets('T-BG-05 · dolna krawędź na suficie nie rośnie, bez zapisu',
        (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 2, height: 1, startX: 2, startY: 2),
        ],
        maxRows: 3,
      );
      final before = tester.getRect(tile('a'));

      await dragInSteps(tester, Offset(before.center.dx, before.bottom - 5),
          const Offset(0, 2 * slot));

      expect(layoutOf(controller, 'a'), '2,2 2x1');
      expect(tester.getRect(tile('a')), before);
      expect(delegate.updated, isEmpty);
    });

    testWidgets('T-BG-06 · rośnie do sufitu i ani wiersza dalej',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
        ],
        maxRows: 3,
      );
      final before = tester.getRect(tile('a'));

      await dragInSteps(tester, Offset(before.center.dx, before.bottom - 5),
          const Offset(0, 4 * slot),
          steps: 10);

      expect(layoutOf(controller, 'a'), '2,0 2x3');
    });

    testWidgets(
        'T-BG-07 · sąsiad na suficie nie zostaje wypchnięty: wzrost '
        'odmówiony', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
          DashboardItem(
              identifier: 'b', width: 2, height: 1, startX: 2, startY: 2),
        ],
        maxRows: 3,
      );
      final before = tester.getRect(tile('a'));

      await dragInSteps(tester, Offset(before.center.dx, before.bottom - 5),
          const Offset(0, 3 * slot),
          steps: 10);

      expect(layoutOf(controller, 'a'), '2,0 2x2');
      expect(layoutOf(controller, 'b'), '2,2 2x1');
      expectUnderCeiling(controller, 3);
    });

    testWidgets('T-BG-08 · sąsiad nad sufitem jest przesuwany w dół, do sufitu',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 2, height: 1, startX: 2, startY: 0),
          DashboardItem(
              identifier: 'b', width: 2, height: 1, startX: 2, startY: 1),
        ],
        maxRows: 3,
      );
      final before = tester.getRect(tile('a'));

      await dragInSteps(tester, Offset(before.center.dx, before.bottom - 5),
          const Offset(0, 3 * slot),
          steps: 10);

      expect(layoutOf(controller, 'a'), '2,0 2x2');
      expect(layoutOf(controller, 'b'), '2,2 2x1');
    });
  });

  group('dodawanie i canPlace', () {
    testWidgets('T-BG-09 · add bez miejsca pod sufitem rzuca, układ bez zmian',
        (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'full', width: 6, height: 2, startX: 0, startY: 0),
        ],
        maxRows: 2,
      );

      expect(controller.canPlace(ItemLayout(width: 1, height: 1)), isFalse);
      expect(
          () => controller.add(DashboardItem(
              identifier: 'x', width: 1, height: 1, startX: 0, startY: 0)),
          throwsA(isA<DashboardNoSpaceException>()
              .having((e) => e.identifier, 'identifier', 'x')
              .having((e) => e.maxRows, 'maxRows', 2)));
      await tester.pumpAndSettle();

      expect(controller.items, ['full']);
      expect(delegate.added, isEmpty);
      expect(tile('x'), findsNothing);
      expect(
          controller.canPlace(
              ItemLayout(startX: 0, startY: 0, width: 6, height: 2),
              ignoreId: 'full'),
          isTrue);
    });

    testWidgets('T-BG-10 · addAll: gdy jeden nie wejdzie, nie dodaje żadnego',
        (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 6, height: 1, startX: 0, startY: 0),
        ],
        maxRows: 2,
      );

      expect(
          () => controller.addAll([
                DashboardItem(identifier: 'b', width: 3, height: 1),
                // `EditModeSettings.shrinkOnMove` (default true) shrinks an
                // added item too; its minimum keeps it from fitting.
                DashboardItem(
                    identifier: 'c', width: 4, height: 1, minWidth: 4),
              ]),
          throwsA(isA<DashboardNoSpaceException>()
              .having((e) => e.identifier, 'identifier', 'c')));
      await tester.pumpAndSettle();

      expect(controller.items, ['a']);
      expect(delegate.added, isEmpty);
      // b's place was given back.
      expect(
          controller
              .canPlace(ItemLayout(startX: 0, startY: 1, width: 6, height: 1)),
          isTrue);

      // And a set that fits goes in.
      controller.addAll([
        DashboardItem(identifier: 'b', width: 3, height: 1),
        DashboardItem(identifier: 'c', width: 3, height: 1),
      ]);
      await tester.pumpAndSettle();
      expect(layoutOf(controller, 'b'), '0,1 3x1');
      expect(layoutOf(controller, 'c'), '3,1 3x1');
      expectUnderCeiling(controller, 2);
    });

    testWidgets('T-BG-11 · add znajduje wolne miejsce pod sufitem',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 6, height: 1, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'b', width: 5, height: 1, startX: 0, startY: 1),
        ],
        maxRows: 2,
      );

      controller.add(DashboardItem(identifier: 'c', width: 1, height: 1));
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'c'), '5,1 1x1');
    });

    testWidgets('T-BG-12 · canPlace: kolumny, sufit, nakładanie, ignoreId',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 2, height: 2, startX: 0, startY: 0),
        ],
        maxRows: 4,
      );
      bool can(int x, int y, int w, int h, [String? ignore]) =>
          controller.canPlace(
              ItemLayout(startX: x, startY: y, width: w, height: h),
              ignoreId: ignore);

      expect(can(2, 0, 4, 4), isTrue);
      expect(can(3, 0, 4, 1), isFalse, reason: 'past the last column');
      expect(can(2, 3, 1, 2), isFalse, reason: 'past the ceiling');
      expect(can(2, 4, 1, 1), isFalse, reason: 'on the ceiling row');
      expect(can(1, 1, 2, 2), isFalse, reason: 'overlaps a');
      expect(can(1, 1, 2, 2, 'a'), isTrue);
      expect(can(1, 1, 2, 2, 'other'), isFalse);
      expect(can(-1, 0, 1, 1), isFalse);
    });

    testWidgets('T-BG-13 · canPlace: wyłączona kolumna wirtualna',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [],
        slotCount: 7,
        virtualColumnsConfig: const VirtualColumnsConfig.visible(
            disabledColumns: [3], disabledColumnWidth: 0.05),
      );

      expect(
          controller
              .canPlace(ItemLayout(startX: 2, startY: 0, width: 2, height: 1)),
          isFalse);
      expect(
          controller
              .canPlace(ItemLayout(startX: 4, startY: 0, width: 2, height: 1)),
          isTrue);
    });

    test('T-BG-14 · canPlace bez zamontowanej siatki rzuca StateError', () {
      final controller = DashboardItemController<DashboardItem>(items: []);
      expect(() => controller.canPlace(ItemLayout(width: 1, height: 1)),
          throwsStateError);
    });

    testWidgets('T-BG-15 · bez sufitu add zawsze się mieści (kontrola)',
        (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, [
        DashboardItem(
            identifier: 'full', width: 6, height: 2, startX: 0, startY: 0),
      ]);

      controller.add(DashboardItem(identifier: 'x', width: 1, height: 1));
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'x'), '0,2 1x1');
      expect(
          controller
              .canPlace(ItemLayout(startX: 0, startY: 40, width: 1, height: 1)),
          isTrue);
    });
  });

  group('wczytanie', () {
    testWidgets(
        'T-BG-16 · element zapisany za sufitem trafia na wolne miejsce pod '
        'nim i jest zgłoszony', (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'b', width: 1, height: 1, startX: 3, startY: 5),
        ],
        maxRows: 2,
      );

      expect(layoutOf(controller, 'a'), '0,0 1x1');
      expect(layoutOf(controller, 'b'), '1,0 1x1');
      expect(delegate.updated, ['b 1,0 1x1']);
    });

    testWidgets('T-BG-17 · element bez miejsca pod sufitem zostaje poza siatką',
        (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 6, height: 1, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'b', width: 1, height: 1, startX: 0, startY: 3),
        ],
        maxRows: 1,
      );

      expect(controller.items, ['a']);
      expect(tile('b'), findsNothing);
      expect(delegate.updated, isEmpty);
    });
  });

  group('przewijanie i tło', () {
    testWidgets(
        'T-BG-18 · zakres przewijania kończy się na ostatnim wierszu, także '
        'w trakcie przeciągania', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(
        tester,
        [
          DashboardItem(
              identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
          DashboardItem(
              identifier: 'z', width: 1, height: 1, startX: 5, startY: 9),
        ],
        maxRows: 10,
        editModeSettings:
            EditModeSettings(resizeCursorSide: 20, scrollWhileEditing: true),
      );
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;

      expect(position().maxScrollExtent, 400);

      // Hold an item at the bottom edge: the auto-scroll runs to the end and
      // the drag row past the content is not added under a ceiling.
      final gesture = await tester.startGesture(
          tester.getRect(tile('a')).center,
          kind: PointerDeviceKind.mouse);
      await tester.pump();
      await moveInSteps(tester, gesture, const Offset(0, 540), steps: 6);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(position().maxScrollExtent, 400);
      expect(position().pixels, lessThanOrEqualTo(400));
      await gesture.up();
      await tester.pumpAndSettle();

      expectUnderCeiling(controller, 10);
      expect(position().maxScrollExtent, 400);
    });

    testWidgets('T-BG-19 · tło slotów tylko dla wierszy pod sufitem',
        (WidgetTester tester) async {
      final rows = <int>{};
      await pumpEditGrid(
        tester,
        [],
        maxRows: 3,
        slotBackgroundBuilder:
            SlotBackgroundBuilder.withFunction((context, item, x, y, editing) {
          rows.add(y);
          return const SizedBox();
        }),
      );

      expect(rows, {0, 1, 2});
    });

    testWidgets('T-BG-20 · z sufitem tło slotów nigdy dla wierszy < 0 '
        '(bez sufitu wiersz -1 zostaje, T-PV2-11)', (WidgetTester tester) async {
      final rows = <int>{};
      await pumpEditGrid(
        tester,
        [],
        maxRows: 8,
        slotBackgroundBuilder:
            SlotBackgroundBuilder.withFunction((context, item, x, y, editing) {
          rows.add(y);
          return const SizedBox();
        }),
      );

      expect(rows, isNotEmpty);
      expect(rows.where((y) => y < 0), isEmpty);
    });
  });
}
