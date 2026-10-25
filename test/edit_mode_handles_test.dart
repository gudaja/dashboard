import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// Resize/delete handles in edit mode.
///
/// Everything here goes through the public API of the package only.
void main() {
  EditModeSettings withHandles() => EditModeSettings(
        resizeHandleBuilder: (context, item, isEditing) => SizedBox(
            key: ValueKey('resize_${item.identifier}'), width: 28, height: 28),
        deleteHandleBuilder: (context, item, isEditing, onDelete) =>
            GestureDetector(
          // An empty SizedBox does not hit-test by itself.
          behavior: HitTestBehavior.opaque,
          onTap: onDelete,
          child: SizedBox(
              key: ValueKey('delete_${item.identifier}'),
              width: 28,
              height: 28),
        ),
      );

  testWidgets(
      'T-EH-02 · przycisk usuwania usuwa element i zapisuje to w delegacie',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 2, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'b', width: 1, height: 1, startX: 3, startY: 0),
      ],
      editModeSettings: withHandles(),
    );

    await tester.tap(find.byKey(const ValueKey('delete_a')));
    await tester.pumpAndSettle();

    expect(controller.items, ['b']);
    expect(tile('a'), findsNothing);
    expect(delegate.deleted, [
      ['a']
    ]);
  });

  testWidgets(
      'T-EH-03 · przeciągnięcie uchwytu rozmiaru powiększa w prawo i w dół',
      (WidgetTester tester) async {
    // With a resizeHandleBuilder the bottom-right 50x50 px of the item resize
    // in both directions, whatever resizeCursorSide is.
    final (controller, delegate) = await pumpEditGrid(
      tester,
      [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 1, startY: 1),
      ],
      editModeSettings: withHandles(),
    );

    await dragInSteps(
        tester,
        tester.getCenter(find.byKey(const ValueKey('resize_a'))),
        const Offset(slot, slot));

    expect(layoutOf(controller, 'a'), '1,1 2x2');
    expect(delegate.updated, ['a 1,1 2x2']);
  });

  testWidgets(
      'T-EH-01 · uchwyty w trybie edycji nie zmieniają rozmiaru kafelka, '
      'który sam nie wypełnia slotu', (WidgetTester tester) async {
    final controller = DashboardItemController<DashboardItem>(items: [
      DashboardItem(identifier: 'a', width: 2, height: 2, startX: 0, startY: 0),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dashboard<DashboardItem>(
          dashboardItemController: controller,
          slotCount: 4,
          slotHeight: 50,
          editModeSettings: EditModeSettings(
            resizeHandleBuilder: (context, item, isEditing) =>
                const SizedBox(key: Key('resize'), width: 10, height: 10),
            deleteHandleBuilder: (context, item, isEditing, onDelete) =>
                const SizedBox(key: Key('delete'), width: 10, height: 10),
          ),
          // A tile with no size of its own — it takes whatever it is given.
          itemBuilder: (item) => const ColoredBox(
              key: Key('tile'), color: Colors.red, child: Text('a')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final outside = tester.getSize(find.byKey(const Key('tile')));

    controller.isEditing = true;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resize')), findsOneWidget);
    expect(find.byKey(const Key('delete')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('tile'))), outside);
  });
}
