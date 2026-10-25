import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resize/delete handles in edit mode.
///
/// Everything here goes through the public API of the package only.
void main() {
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
