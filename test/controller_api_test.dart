import 'dart:async';

import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// Public controller and widget API without a test of its own so far:
/// addAll / deleteAll, errorPlaceholder and onGridDimensionsChanged.
///
/// Everything here goes through the public API of the package only.
void main() {
  testWidgets('T-C-01 · addAll dodaje wszystkie elementy jednym zapisem',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
    ]);

    controller.addAll([
      DashboardItem(identifier: 'b', width: 1, height: 1),
      DashboardItem(identifier: 'c', width: 2, height: 1),
    ]);
    await tester.pumpAndSettle();

    expect(controller.items, unorderedEquals(['a', 'b', 'c']));
    expect(tile('b'), findsOneWidget);
    expect(tile('c'), findsOneWidget);
    expect(delegate.added, [
      ['b', 'c']
    ]);
    final rects = ['a', 'b', 'c'].map((id) => tester.getRect(tile(id)));
    for (final r in rects) {
      for (final other in rects.where((o) => o != r)) {
        expect(r.overlaps(other), isFalse, reason: '$r / $other');
      }
    }
  });

  testWidgets('T-C-02 · deleteAll usuwa wskazane elementy jednym zapisem',
      (WidgetTester tester) async {
    final (controller, delegate) = await pumpEditGrid(tester, [
      DashboardItem(identifier: 'a', width: 1, height: 1, startX: 0, startY: 0),
      DashboardItem(identifier: 'b', width: 1, height: 1, startX: 1, startY: 0),
      DashboardItem(identifier: 'c', width: 1, height: 1, startX: 2, startY: 0),
    ]);

    controller.deleteAll(['a', 'c']);
    await tester.pumpAndSettle();

    expect(controller.items, ['b']);
    expect(tile('a'), findsNothing);
    expect(tile('c'), findsNothing);
    expect(delegate.deleted, [
      ['a', 'c']
    ]);
  });

  testWidgets(
      'T-C-03 · błąd ładowania z delegata pokazuje errorPlaceholder z tym '
      'błędem', (WidgetTester tester) async {
    Object? shown;
    final controller = DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: _FailingDelegate());

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dashboard<DashboardItem>(
          dashboardItemController: controller,
          slotCount: 4,
          slotHeight: 50,
          errorPlaceholder: (error, stackTrace) {
            shown = error;
            return const SizedBox(key: Key('error'));
          },
          itemBuilder: (item) => const SizedBox(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('error')), findsOneWidget);
    expect(shown, isA<StateError>());
  });

  testWidgets('T-C-04 · onGridDimensionsChanged podaje wymiary siatki',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reported = <GridDimensions>[];

    Widget grid(double width) => MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Dashboard<DashboardItem>(
                  dashboardItemController:
                      DashboardItemController<DashboardItem>(items: []),
                  slotCount: 4,
                  slotHeight: 50,
                  padding: const EdgeInsets.all(20),
                  horizontalSpace: 6,
                  verticalSpace: 8,
                  onGridDimensionsChanged: reported.add,
                  itemBuilder: (item) => const SizedBox(),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(grid(440));
    await tester.pumpAndSettle();

    final d = reported.last;
    expect(d.columns, 4);
    expect(d.totalWidth, 400, reason: '440 minus the 2x20 padding');
    expect(d.slotWidth, 100);
    expect(d.slotHeight, 50);
    expect(d.padding, const EdgeInsets.all(20));
    expect(d.horizontalSpace, 6);
    expect(d.verticalSpace, 8);

    // A narrower grid reports again, with the new slot width.
    await tester.pumpWidget(grid(240));
    await tester.pumpAndSettle();
    expect(reported.last.totalWidth, 200);
    expect(reported.last.slotWidth, 50);
  });

  testWidgets(
      'T-C-05 · przy kolumnach wirtualnych slotWidth to szerokość kolumny '
      'włączonej, ta, w której stoją kafelki', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    GridDimensions? reported;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dashboard<DashboardItem>(
          dashboardItemController:
              DashboardItemController<DashboardItem>(items: [
            DashboardItem(
                identifier: 'a', width: 1, height: 1, startX: 1, startY: 0),
          ]),
          slotCount: 7,
          slotHeight: 50,
          horizontalSpace: 4,
          verticalSpace: 4,
          slideToTop: false,
          // 600 px: one disabled column of 5% (30 px), six enabled of 95 px.
          virtualColumnsConfig: const VirtualColumnsConfig.visible(
              disabledColumns: [3], disabledColumnWidth: 0.05),
          onGridDimensionsChanged: (d) => reported = d,
          itemBuilder: (item) => ColoredBox(
              key: Key('tile_${item.identifier}'), color: Colors.red),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(reported!.slotWidth, 95, reason: 'not 600 / 7 = 85.7');
    // An item away from the edges has half the spacing on each side.
    expect(tester.getSize(find.byKey(const Key('tile_a'))).width,
        reported!.slotWidth - 4);
  });

  testWidgets(
      'T-C-06 · horizontalSpace rozsuwa kafelki w poziomie, verticalSpace w '
      'pionie', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dashboard<DashboardItem>(
          dashboardItemController:
              DashboardItemController<DashboardItem>(items: [
            DashboardItem(
                identifier: 'a', width: 1, height: 1, startX: 1, startY: 1),
            DashboardItem(
                identifier: 'right', width: 1, height: 1, startX: 2, startY: 1),
            DashboardItem(
                identifier: 'below', width: 1, height: 1, startX: 1, startY: 2),
          ]),
          slotCount: 4,
          slotHeight: 100,
          slideToTop: false,
          horizontalSpace: 2,
          verticalSpace: 20,
          itemBuilder: (item) => ColoredBox(
              key: Key('tile_${item.identifier}'), color: Colors.red),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final a = tester.getRect(find.byKey(const Key('tile_a')));
    final right = tester.getRect(find.byKey(const Key('tile_right')));
    final below = tester.getRect(find.byKey(const Key('tile_below')));
    expect(right.left - a.right, 2);
    expect(below.top - a.bottom, 20);
    expect(a.size, const Size(98, 80));
  });
}

class _FailingDelegate extends DashboardItemStorageDelegate<DashboardItem> {
  @override
  bool get cacheItems => false;

  @override
  bool get layoutsBySlotCount => false;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) =>
      Future<List<DashboardItem>>.error(StateError('storage unavailable'));

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {}
}
