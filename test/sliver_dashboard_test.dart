import 'dart:async';

import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// SliverDashboard: the grid as a sliver of a `CustomScrollView`, under a
/// 200 px `SliverAppBar` pinned at its 56 px toolbar.
///
/// Everything here goes through the public API of the package only.
void main() {
  /// Items in column 1 of rows 0, 2, 4, …, 2 × ([rows] − 1), 100 px each.
  List<DashboardItem> column(int rows) => [
        for (var y = 0; y < rows; y++)
          DashboardItem(
              identifier: 'r$y', width: 1, height: 1, startX: 1, startY: y * 2),
      ];

  testWidgets(
      'T-SD-01 · siatka przewija się razem z pasmem, a budują się tylko '
      'kafelki z pasma widoku', (WidgetTester tester) async {
    final built = <String>{};
    final (controller, outer) =
        await _pumpSliver(tester, column(50), itemBuilder: (item) {
      built.add(item.identifier);
      return _tile(item);
    });

    final r2 = tester.getRect(tile('r2')).top;
    expect(r2, moreOrLessEquals(200 + 400 + 4),
        reason: 'below the expanded band, row 4 of 100 px, half a spacing');

    outer.jumpTo(300);
    await tester.pump();
    expect(tester.getRect(tile('r2')).top, moreOrLessEquals(r2 - 300));
    expect(tester.getRect(tile('r6')).top, moreOrLessEquals(r2 - 300 + 800));

    // 100 rows of content, 800 px of viewport and 500 px of cache either way.
    expect(built.length, lessThan(15),
        reason: 'built: ${built.length} of ${controller.items.length}');
    expect(built, isNot(contains('r40')));

    outer.jumpTo(7000);
    await tester.pump();
    expect(built, contains('r40'), reason: 'built when scrolled to');
    expect(tester.getRect(tile('r40')).top,
        moreOrLessEquals(200 + 8000 + 4 - 7000));
  });

  testWidgets(
      'T-SD-02 · kafelek jest trafiany tam, gdzie jest narysowany, po '
      'przewinięciu', (WidgetTester tester) async {
    final taps = <String>[];
    final (_, outer) = await _pumpSliver(tester, column(20),
        itemBuilder: (item) => GestureDetector(
            onTap: () => taps.add(item.identifier), child: _tile(item)));

    outer.jumpTo(1000);
    await tester.pumpAndSettle();
    // Row 12 of the content: 200 + 1200 − 1000 = 400 on the screen.
    await tester.tap(tile('r6'));
    expect(taps, ['r6']);
  });

  testWidgets(
      'T-SD-03 · w edycji przeciągnięcie pustego pola przewija scroll view, '
      'a przytrzymany kafelek się przesuwa', (WidgetTester tester) async {
    final (controller, outer) = await _pumpSliver(tester, column(20));
    controller.isEditing = true;
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(450, 500), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(outer.offset, greaterThan(200));

    outer.jumpTo(0);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getRect(tile('r1')).center,
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.liftedItem.value, 'r1');
    await moveInSteps(tester, gesture, const Offset(2 * slot, slot));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(layoutOf(controller, 'r1'), '3,3 1x1');
    expect(outer.offset, 0);
  });

  testWidgets(
      'T-SD-04 · autoscroll w dół zwija pasmo, potem przewija siatkę, '
      'kafelek zostaje pod kursorem', (WidgetTester tester) async {
    final notifications = <ScrollNotification>[];
    final (controller, outer) =
        await _pumpSliver(tester, column(10), notifications: notifications);
    controller.isEditing = true;
    await tester.pumpAndSettle();

    const at = Offset(150, 790);
    final gesture = await tester.startGesture(tester.getRect(tile('r0')).center,
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveTo(at);
    await tester.pump();

    final offsets = <double>[];
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      offsets.add(outer.offset);
    }
    expect(offsets.first, inExclusiveRange(0, 50), reason: 'step by step');
    for (var i = 1; i < offsets.length; i++) {
      expect(offsets[i], greaterThanOrEqualTo(offsets[i - 1]));
    }
    // 19 rows of content + one while an item moves, under a 200 px band, in
    // an 800 px viewport: 200 + 2000 − 800.
    expect(outer.position.maxScrollExtent, 1400);
    expect(outer.offset, 1400);
    expect(tester.getRect(tile('r0')).contains(at), isTrue);

    notifications.clear();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(notifications, isEmpty, reason: 'the steps stop at the end');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.liftedItem.value, isNull);
    expect(int.parse(layoutOf(controller, 'r0').split(',')[1].split(' ')[0]),
        greaterThan(15),
        reason: 'dropped near the end of the grid');
  });

  testWidgets(
      'T-SD-05 · strefa górnej krawędzi zaczyna się pod przypiętym paskiem',
      (WidgetTester tester) async {
    final (controller, outer) = await _pumpSliver(tester, column(20));
    controller.isEditing = true;
    await tester.pumpAndSettle();
    outer.jumpTo(1500);
    await tester.pumpAndSettle();

    final r9 = tester.getRect(tile('r9'));
    final gesture =
        await tester.startGesture(r9.center, kind: PointerDeviceKind.mouse);
    await tester.pump();
    // Just under the 56 px toolbar: in the top zone of the visible grid.
    await gesture.moveTo(Offset(r9.center.dx, 70));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(outer.offset, lessThan(1500));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'T-SD-06 · karuzela w scroll view: swipe przesuwa siatkę, pasmo stoi, '
      'kafelek przy krawędzi zmienia sekcję', (WidgetTester tester) async {
    final (controller, outer) = await _pumpCarousel(tester);
    final band = tester.getRect(find.text('band'));
    final s0 = tester.getRect(tile('s0'));

    await tester.timedDragFrom(const Offset(300, 600), const Offset(-200, 0),
        const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Sekcja 2 z 4'), findsOneWidget);
    expect(tester.getRect(find.text('band')), band, reason: 'the band stays');
    expect(tester.getRect(tile('s1')).left, moreOrLessEquals(s0.left),
        reason: 'section 2 where section 1 was');

    // Edit mode: an item held at the right edge flips to section 3.
    controller.isEditing = true;
    await tester.pumpAndSettle();
    final s1 = tester.getRect(tile('s1'));
    final at = Offset(360, s1.center.dy);
    final gesture =
        await tester.startGesture(s1.center, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveTo(at);
    for (var i = 0; i < 55; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('Sekcja 3 z 4'), findsOneWidget);
    expect(tester.getRect(tile('s1')).contains(at), isTrue);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Sekcja 3 z 4'), findsOneWidget);
    final x = int.parse(layoutOf(controller, 's1').split(',')[0]);
    expect(x, inInclusiveRange(12, 17), reason: 'landed in section 3');
    expect(outer.offset, 0);
  });

  testWidgets('T-SD-07 · nowy kafelek na dole wydłuża zakres przewijania',
      (WidgetTester tester) async {
    final (controller, outer) = await _pumpSliver(tester, column(10));
    final before = outer.position.maxScrollExtent;

    controller.add(
        DashboardItem(
            identifier: 'last', width: 1, height: 1, startX: 0, startY: 30),
        mountToTop: false);
    await tester.pumpAndSettle();

    expect(outer.position.maxScrollExtent, moreOrLessEquals(before + 1200));
  });

  testWidgets(
      'T-SD-08 · delegat w trakcie ładowania: placeholder wypełnia resztę '
      'widoku', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final completer = Completer<List<DashboardItem>>();
    final controller = DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: _SlowDelegate(completer.future));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverDashboard<DashboardItem>(
            dashboardItemController: controller,
            slotCount: 6,
            slotHeight: slot,
            loadingPlaceholder: const Text('loading'),
            itemBuilder: _tile,
          ),
        ]),
      ),
    ));
    expect(find.text('loading'), findsOneWidget);

    completer.complete(column(3));
    await tester.pumpAndSettle();
    expect(find.text('loading'), findsNothing);
    expect(tile('r2'), findsOneWidget);
  });
}

Widget _tile(DashboardItem item) =>
    ColoredBox(key: ValueKey('tile_${item.identifier}'), color: Colors.red);

/// [items] in a 6-column [SliverDashboard] of 100 px rows under the band.
Future<(DashboardItemController<DashboardItem>, ScrollController)> _pumpSliver(
  WidgetTester tester,
  List<DashboardItem> items, {
  DashboardItemBuilder<DashboardItem> itemBuilder = _tile,
  List<ScrollNotification>? notifications,
}) async {
  tester.view.physicalSize = const Size(600, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = DashboardItemController<DashboardItem>(items: items);
  final outer = ScrollController();
  addTearDown(outer.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          notifications?.add(n);
          return false;
        },
        child: CustomScrollView(controller: outer, slivers: [
          const SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(title: Text('band'))),
          SliverDashboard<DashboardItem>(
            dashboardItemController: controller,
            slotCount: 6,
            slotHeight: slot,
            slideToTop: false,
            shrinkToPlace: false,
            itemBuilder: itemBuilder,
          ),
        ]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (controller, outer);
}

/// A phone-wide carousel of 24 columns in sections of 6, its grid a
/// [SliverDashboard] under the band; `s<n>` in the second column of section n.
Future<(DashboardItemController<DashboardItem>, ScrollController)>
    _pumpCarousel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = DashboardItemController<DashboardItem>(items: [
    for (var s = 0; s < 4; s++)
      DashboardItem(
          identifier: 's$s', width: 1, height: 1, startX: s * 6 + 1, startY: 0),
  ]);
  final outer = ScrollController();
  addTearDown(outer.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MobileDashboardWrapper<DashboardItem>(
        dashboardItemController: controller,
        slotCount: 24,
        columnsPerPage: 6,
        mobileConfig: const MobileCarouselConfig(swipeWhileEditing: true),
        dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) =>
            SliverDashboard<DashboardItem>(
          dashboardItemController: ctrl,
          slotCount: slotCount,
          slotHeight: 40,
          // The wrapper sizes its pages for a grid padded by 8.
          padding: const EdgeInsets.all(8),
          slideToTop: false,
          shrinkToPlace: false,
          itemBuilder: _tile,
        ),
        scrollViewBuilder: (context, grid) =>
            CustomScrollView(controller: outer, slivers: [
          const SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(title: Text('band'))),
          grid,
        ]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (controller, outer);
}

class _SlowDelegate extends DashboardItemStorageDelegate<DashboardItem> {
  _SlowDelegate(this.items);

  final Future<List<DashboardItem>> items;

  @override
  bool get cacheItems => false;

  @override
  bool get layoutsBySlotCount => false;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) => items;

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {}
}
