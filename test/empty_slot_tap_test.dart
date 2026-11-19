import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// `Dashboard.onEmptySlotTap`: a tap on a slot no item occupies.
///
/// The grid of `pumpEditGrid`: 6 columns of 100 px slots in a 600x600 view.
void main() {
  /// The centre of slot ([x], [y]) on screen (the grid starts at 0,0).
  Offset slotCentre(int x, int y) => Offset((x + 0.5) * slot, (y + 0.5) * slot);

  List<DashboardItem> items() => [
        DashboardItem(
            identifier: 'a', width: 2, height: 1, startX: 0, startY: 0),
      ];

  for (final editing in [false, true]) {
    testWidgets(
        'T-ET-01 · stuknięcie w pusty slot zgłasza (x, y) — edycja: $editing',
        (WidgetTester tester) async {
      final taps = <String>[];
      await pumpEditGrid(tester, items(),
          maxRows: 4,
          editing: editing,
          onEmptySlotTap: (x, y) => taps.add('$x,$y'));

      await tester.tapAt(slotCentre(3, 2));
      await tester.pumpAndSettle();
      await tester.tapAt(slotCentre(0, 1));
      await tester.pumpAndSettle();

      expect(taps, ['3,2', '0,1']);
    });

    testWidgets(
        'T-ET-02 · nie na elemencie i nie za sufitem — edycja: $editing',
        (WidgetTester tester) async {
      final taps = <String>[];
      await pumpEditGrid(tester, items(),
          maxRows: 4,
          editing: editing,
          onEmptySlotTap: (x, y) => taps.add('$x,$y'));

      await tester.tapAt(slotCentre(1, 0)); // on a
      await tester.pumpAndSettle();
      await tester.tapAt(slotCentre(2, 4)); // first row past the ceiling
      await tester.pumpAndSettle();
      await tester.tapAt(slotCentre(5, 5));
      await tester.pumpAndSettle();

      expect(taps, isEmpty);
    });
  }

  testWidgets('T-ET-03 · przeciągnięcie po pustym slocie to nie stuknięcie',
      (WidgetTester tester) async {
    final taps = <String>[];
    await pumpEditGrid(tester, items(),
        editing: false, onEmptySlotTap: (x, y) => taps.add('$x,$y'));

    await dragInSteps(tester, slotCentre(3, 2), const Offset(0, -150));
    await tester.longPressAt(slotCentre(4, 3));
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
  });

  testWidgets(
      'T-ET-04 · z onEmptySlotTap przeciąganie i zmiana rozmiaru działają '
      'jak dotąd', (WidgetTester tester) async {
    final taps = <String>[];
    final (controller, delegate) = await pumpEditGrid(tester, items(),
        onEmptySlotTap: (x, y) => taps.add('$x,$y'));

    await dragInSteps(tester, tester.getRect(tile('a')).center,
        const Offset(2 * slot, 2 * slot),
        steps: 8);
    expect(layoutOf(controller, 'a'), '2,2 2x1');

    final r = tester.getRect(tile('a'));
    await dragInSteps(
        tester, Offset(r.right - 5, r.center.dy), const Offset(slot, 0));
    expect(layoutOf(controller, 'a'), '2,2 3x1');
    expect(delegate.updated, ['a 2,2 2x1', 'a 2,2 3x1']);
    expect(taps, isEmpty);
  });

  testWidgets(
      'T-ET-05 · scrollWhileEditing: stuknięcie zgłasza, przewijanie i '
      'przeciąganie działają', (WidgetTester tester) async {
    final taps = <String>[];
    final (controller, _) = await pumpEditGrid(
      tester,
      [
        ...items(),
        DashboardItem(
            identifier: 'z', width: 1, height: 1, startX: 5, startY: 11),
      ],
      editModeSettings:
          EditModeSettings(resizeCursorSide: 20, scrollWhileEditing: true),
      onEmptySlotTap: (x, y) => taps.add('$x,$y'),
    );
    ScrollPosition position() =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    await tester.tapAt(slotCentre(4, 1));
    await tester.pumpAndSettle();
    expect(taps, ['4,1']);

    // A drag on an empty slot scrolls the grid.
    await dragInSteps(tester, slotCentre(3, 4), const Offset(0, -200));
    expect(position().pixels, greaterThan(100));
    expect(taps, ['4,1']);

    // A tap after the scroll reports the content row.
    final pixels = position().pixels;
    await tester.tapAt(Offset(3.5 * slot, 2.5 * slot));
    await tester.pumpAndSettle();
    expect(taps.last, '3,${((2.5 * slot + pixels) / slot).floor()}');

    // An item is still dragged (a mouse picks it up on its first move).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await dragInSteps(
        tester, tester.getRect(tile('a')).center, const Offset(2 * slot, slot),
        steps: 8, kind: PointerDeviceKind.mouse);
    expect(layoutOf(controller, 'a'), '2,1 2x1');
  });

  testWidgets('T-ET-06 · wyłączona kolumna wirtualna nie jest slotem',
      (WidgetTester tester) async {
    final taps = <String>[];
    await pumpEditGrid(
      tester,
      [],
      slotCount: 7,
      editing: false,
      virtualColumnsConfig: const VirtualColumnsConfig.visible(
          disabledColumns: [0], disabledColumnWidth: 0.05),
      onEmptySlotTap: (x, y) => taps.add('$x,$y'),
    );

    await tester.tapAt(const Offset(10, 50)); // inside the narrow column 0
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 50)); // column 1
    await tester.pumpAndSettle();

    expect(taps, ['1,0']);
  });
}
