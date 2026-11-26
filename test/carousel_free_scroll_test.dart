import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// 1.5.0: a carousel wider than the screen scrolled freely
/// (`pageSnapping: false`) — the end clamp, the fling, a touch that stops the
/// fling, and the position indicator.
///
/// The scene is a 390 px phone with `columnsPerPage: 6`: the wrapper sizes a
/// slot as `(390 - 2 * 8) / 6`. Row 0 holds one item `wide` across the whole
/// grid (a tap target wherever the grid stands), row 1 a marker `c0` in
/// column 0 and `cl` in the last column.
void main() {
  for (final n in [7, 8, 10, 16]) {
    testWidgets(
        'T-CS-01 · n = $n, pageSnapping: false: koniec przewijania bez '
        'pustych kolumn, powrót do kolumny 0', (WidgetTester tester) async {
      await _pump(tester,
          n: n, config: const MobileCarouselConfig(pageSnapping: false));
      final home = tester.getRect(_tile('c0')).left;

      await tester.timedDragFrom(
          const Offset(300, 300), const Offset(-1500, 0), _slow);
      await tester.pumpAndSettle();

      expect(_offset(tester), moreOrLessEquals((n - 6) * _slotWidth),
          reason: 'clamped to the last full screen');
      expect(tester.getRect(_tile('cl')).right,
          moreOrLessEquals(_phone.width - _padding, epsilon: 0.5),
          reason: 'the last column ends at the right edge of the view');

      await tester.timedDragFrom(
          const Offset(100, 300), const Offset(1500, 0), _slow);
      await tester.pumpAndSettle();

      expect(_offset(tester), 0);
      expect(tester.getRect(_tile('c0')).left, home);
    });
  }

  testWidgets(
      'T-CS-02 · pageSnapping: true: ostatnia strona n = 10 sklamrowana jak '
      'w T-CS-01, n = 24 strony co 6 kolumn', (WidgetTester tester) async {
    await _pump(tester, n: 10, config: const MobileCarouselConfig());
    expect(_dots, findsNWidgets(2));

    await tester.tap(_dot(1));
    await tester.pumpAndSettle();
    expect(_offset(tester), moreOrLessEquals(4 * _slotWidth));
    expect(tester.getRect(_tile('cl')).right,
        moreOrLessEquals(_phone.width - _padding, epsilon: 0.5));

    // A swipe back and a swipe forward land on the same clamped page.
    await tester.timedDragFrom(
        const Offset(100, 300), const Offset(200, 0), _slow);
    await tester.pumpAndSettle();
    expect(_offset(tester), 0);
    await tester.timedDragFrom(
        const Offset(300, 300), const Offset(-200, 0), _slow);
    await tester.pumpAndSettle();
    expect(_offset(tester), moreOrLessEquals(4 * _slotWidth));

    await _pump(tester, n: 24, config: const MobileCarouselConfig());
    expect(_dots, findsNWidgets(4));
    for (var page = 1; page < 4; page++) {
      await tester.tap(_dot(page));
      await tester.pumpAndSettle();
      expect(_offset(tester), moreOrLessEquals(6 * page * _slotWidth),
          reason: 'page $page');
    }
  });

  testWidgets(
      'T-CS-03 · kolumny wirtualne (20, [6, 13], 0,03): offsety stron telefonu '
      'i tabletu jak wzór sprzed zmiany', (WidgetTester tester) async {
    const vc = VirtualColumnsConfig.visible(
        disabledColumns: [6, 13], disabledColumnWidth: 0.03);
    const config = MobileCarouselConfig(
      visibleSectionsOnMobile: 1,
      visibleSectionsOnTablet: 2,
      sectionStepOnTablet: 2,
      showHeader: false,
    );
    // The wrapper's formula for a slot next to disabled columns.
    const ratio = 0.03 * 18 / (1 - 2 * 0.03);
    double offsetOf(int column, double visibleSlots, double width) {
      final slotWidth = (width - 2 * _padding) / visibleSlots;
      final resolved = slotWidth * 18 / (1 - 2 * 0.03);
      return vc.getColumnPosition(column, slotWidth, resolved);
    }

    for (final (size, starts, visible) in [
      (_phone, [0, 7, 14], 6.0),
      (const Size(800, 600), [0, 7], 12 + ratio),
    ]) {
      await _pump(tester,
          n: 20, config: config, virtualColumnsConfig: vc, size: size);
      expect(_dots, findsNWidgets(starts.length));
      for (var page = starts.length - 1; page >= 0; page--) {
        await tester.tap(_dot(page));
        await tester.pumpAndSettle();
        expect(_offset(tester),
            moreOrLessEquals(offsetOf(starts[page], visible, size.width)),
            reason: '$size page $page');
      }
    }
  });

  testWidgets(
      'T-CS-04 · freeScrollFling: siatka jedzie dalej po puszczeniu i staje '
      'w [0, max]; bez niej staje w miejscu puszczenia',
      (WidgetTester tester) async {
    const max = 10 * _slotWidth;
    Future<void> flingLeft() =>
        tester.flingFrom(const Offset(300, 300), const Offset(-100, 0), 1500);

    // Off (the default): T-SN-02 unchanged — the grid stays where released.
    await _pump(tester,
        n: 16, config: const MobileCarouselConfig(pageSnapping: false));
    await flingLeft();
    await tester.pump();
    final released = _offset(tester);
    expect(released, greaterThan(90));
    await tester.pumpAndSettle();
    expect(_offset(tester), released, reason: 'no fling by default');

    await _pump(tester,
        n: 16,
        config: const MobileCarouselConfig(
            pageSnapping: false, freeScrollFling: true));
    await flingLeft();
    await tester.pump();
    expect(_offset(tester), released, reason: 'released at the same place');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_offset(tester), greaterThan(released + 1), reason: 'still moving');
    await tester.pumpAndSettle();
    final stop = _offset(tester);
    expect(stop, greaterThan(released + 1));
    expect(stop, lessThanOrEqualTo(max));

    for (var i = 0; i < 3; i++) {
      await tester.flingFrom(
          const Offset(300, 300), const Offset(-200, 0), 6000);
      await tester.pumpAndSettle();
    }
    expect(_offset(tester), max, reason: 'stops exactly at the end');

    for (var i = 0; i < 3; i++) {
      await tester.flingFrom(const Offset(80, 300), const Offset(200, 0), 6000);
      await tester.pumpAndSettle();
    }
    expect(_offset(tester), 0, reason: 'and exactly at the start');
  });

  testWidgets(
      'T-CS-05 · dotyk w trakcie bezwładności zatrzymuje siatkę i nie trafia '
      'w kafelek; po zatrzymaniu tap działa', (WidgetTester tester) async {
    final scene = await _pump(tester,
        n: 16,
        config: const MobileCarouselConfig(
            pageSnapping: false, freeScrollFling: true));
    final row0 = tester.getRect(_tile('wide')).center.dy;

    await tester.flingFrom(const Offset(300, 300), const Offset(-60, 0), 2000);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final moving = _offset(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(_offset(tester), greaterThan(moving), reason: 'the fling runs');

    await tester.tapAt(Offset(200, row0));
    await tester.pump();
    final stopped = _offset(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_offset(tester), stopped, reason: 'the touch stopped the fling');
    expect(scene.taps, 0, reason: 'and did not reach the item');

    await tester.pumpAndSettle();
    expect(_offset(tester), stopped);
    await tester.tapAt(Offset(200, row0));
    await tester.pumpAndSettle();
    expect(scene.taps, 1, reason: 'a tap on a still grid reaches the item');

    // A finger that only rests on the grid stops it at once, also when an
    // ancestor (a band, a vertical scroll) competes for the touch and the
    // carousel's drag has not won the arena yet.
    final held = await _pump(tester,
        n: 16,
        config: const MobileCarouselConfig(
            pageSnapping: false, freeScrollFling: true),
        ancestorVerticalDrag: true);
    await tester.flingFrom(const Offset(300, 300), const Offset(-60, 0), 2000);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final finger = await tester.startGesture(Offset(200, row0));
    await tester.pump();
    final rest = _offset(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_offset(tester), rest, reason: 'a resting finger stops the fling');
    await finger.up();
    await tester.pumpAndSettle();
    expect(_offset(tester), rest);
    expect(held.taps, 0);
  });

  testWidgets(
      'T-CS-06 · indicatorBuilder: metryki przewijania, bez kropek, siatka '
      'jak przy showDots: false; n ≤ 6 — budowniczy nie wołany',
      (WidgetTester tester) async {
    final calls = <CarouselScrollMetrics>[];
    Widget indicator(BuildContext context, CarouselScrollMetrics metrics) {
      calls.add(metrics);
      return const SizedBox(key: Key('indicator'), height: 4);
    }

    await _pump(tester,
        n: 10,
        config:
            const MobileCarouselConfig(pageSnapping: false, showDots: false));
    final noDots = tester.getRect(find.byType(Dashboard<DashboardItem>));

    await _pump(tester,
        n: 10,
        config: MobileCarouselConfig(
            pageSnapping: false, indicatorBuilder: indicator));
    expect(calls, isNotEmpty);
    final metrics = calls.last;
    expect(metrics.maxOffset, moreOrLessEquals(4 * _slotWidth));
    expect(metrics.viewportWidth, _phone.width);
    expect(metrics.contentWidth, _phone.width - 2 * _padding);
    expect(metrics.offset.value, 0);
    expect(_dots, findsNothing, reason: 'the indicator replaces the dots');
    expect(tester.getRect(find.byType(Dashboard<DashboardItem>)), noDots,
        reason: 'the indicator takes no room from the grid');
    final bar = tester.getRect(find.byKey(const Key('indicator')));
    expect(bar.bottom, _phone.height, reason: 'at the bottom of the carousel');
    expect(bar.width, _phone.width);

    await tester.timedDragFrom(
        const Offset(300, 300), const Offset(-100, 0), _slow);
    await tester.pumpAndSettle();
    expect(calls.last.offset.value, moreOrLessEquals(100));
    expect(calls.last.offset.value, moreOrLessEquals(_offset(tester)));

    for (final small in [6, 4]) {
      calls.clear();
      await _pump(tester,
          n: small,
          config: MobileCarouselConfig(
              pageSnapping: false, indicatorBuilder: indicator));
      expect(calls, isEmpty, reason: 'n = $small fits the screen');
      expect(find.byKey(const Key('indicator')), findsNothing);
    }
  });

  testWidgets(
      'T-CS-07 · edycja n = 10: kafelek przy prawej krawędzi po pageFlipDwell '
      'przenosi siatkę na sklamrowany koniec i ląduje w kolumnie ≥ 6',
      (WidgetTester tester) async {
    final scene = await _pump(tester,
        n: 10,
        items: [
          DashboardItem(
              identifier: 'm', width: 1, height: 1, startX: 1, startY: 0),
        ],
        config: const MobileCarouselConfig(
            pageSnapping: false,
            freeScrollFling: true,
            swipeWhileEditing: true),
        editModeSettings: EditModeSettings(scrollWhileEditing: true),
        editing: true);
    final m = tester.getRect(_tile('m'));
    final at = Offset(360, m.center.dy);

    final gesture =
        await tester.startGesture(m.center, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveTo(at);
    await tester.pump();

    await _pumpFor(tester, const Duration(milliseconds: 400));
    expect(_offset(tester), 0, reason: 'dwell');
    await _pumpFor(tester, const Duration(milliseconds: 450));
    expect(_offset(tester), moreOrLessEquals(4 * _slotWidth),
        reason: 'the last page, clamped');
    await _pumpFor(tester, const Duration(milliseconds: 850));
    expect(_offset(tester), moreOrLessEquals(4 * _slotWidth),
        reason: 'nothing past the end');
    expect(tester.getRect(_tile('m')).contains(at), isTrue,
        reason: 'the item stayed under the pointer');
    expect(scene.delegate.updated, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    final startX = scene.controller.allItems.single.layoutData.startX;
    expect(startX, greaterThanOrEqualTo(6));
    expect(scene.delegate.updated, ['m $startX,0 1x1'],
        reason: 'onItemsUpdated once');
  });

  testWidgets(
      'T-CS-08 · przeciąganie i bezwładność nie wołają itemBuildera ani '
      'dashboardBuildera', (WidgetTester tester) async {
    final scene = await _pump(tester,
        n: 16,
        config: MobileCarouselConfig(
            pageSnapping: false,
            freeScrollFling: true,
            indicatorBuilder: (context, metrics) => const SizedBox(height: 4)));
    scene.itemBuilds = 0;
    scene.gridBuilds = 0;

    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    for (var f = 0; f < 5; f++) {
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final dragged = _offset(tester);
    expect(dragged, greaterThan(100), reason: 'the drag moved the grid');

    await tester.flingFrom(const Offset(300, 300), const Offset(-60, 0), 2000);
    for (var f = 0; f < 10; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_offset(tester), greaterThan(dragged + 60),
        reason: 'the fling moved the grid');
    await tester.pumpAndSettle();

    expect(scene.itemBuilds, 0);
    expect(scene.gridBuilds, 0);
  });
}

const _phone = Size(390, 700);
const double _padding = 8;
const double _slotWidth = (390 - 2 * _padding) / 6;
const _slow = Duration(milliseconds: 800);

Finder _tile(String id) => find.byKey(Key('tile_$id'));

/// How far the grid is moved left.
double _offset(WidgetTester tester) =>
    -tester.getTopLeft(find.byType(Dashboard<DashboardItem>)).dx;

/// The carousel dots: the only round [AnimatedContainer]s here.
final Finder _dots = find.byWidgetPredicate((w) =>
    w is AnimatedContainer &&
    (w.decoration as BoxDecoration?)?.shape == BoxShape.circle);

Finder _dot(int index) => _dots.at(index);

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < total; t += frame) {
    await tester.pump(frame);
  }
}

class _Scene {
  _Scene(this.controller, this.delegate);

  final DashboardItemController<DashboardItem> controller;
  final RecordingDelegate delegate;
  int taps = 0;
  int itemBuilds = 0;
  int gridBuilds = 0;
}

Future<_Scene> _pump(
  WidgetTester tester, {
  required int n,
  required MobileCarouselConfig config,
  List<DashboardItem>? items,
  VirtualColumnsConfig? virtualColumnsConfig,
  EditModeSettings? editModeSettings,
  bool editing = false,
  Size size = _phone,
  bool ancestorVerticalDrag = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final delegate = RecordingDelegate(items ??
      [
        if (virtualColumnsConfig == null)
          DashboardItem(
              identifier: 'wide', width: n, height: 1, startX: 0, startY: 0),
        DashboardItem(
            identifier: 'c0', width: 1, height: 1, startX: 0, startY: 1),
        DashboardItem(
            identifier: 'cl', width: 1, height: 1, startX: n - 1, startY: 1),
      ]);
  final controller = DashboardItemController<DashboardItem>.withDelegate(
      itemStorageDelegate: delegate);
  final scene = _Scene(controller, delegate);

  // A fresh key: a second pump in one test mounts a fresh carousel.
  final Widget carousel = MobileDashboardWrapper<DashboardItem>(
    dashboardItemController: controller,
    slotCount: n,
    columnsPerPage: 6,
    virtualColumnsConfig: virtualColumnsConfig,
    mobileConfig: config,
    dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) {
      scene.gridBuilds++;
      return Dashboard<DashboardItem>(
        dashboardItemController: ctrl,
        slotCount: slotCount,
        slotHeight: 40,
        // The wrapper sizes its pages for a grid padded by 8.
        padding: const EdgeInsets.all(_padding),
        slideToTop: false,
        shrinkToPlace: false,
        virtualColumnsConfig: virtualColumnsConfig,
        editModeSettings: editModeSettings ?? EditModeSettings(),
        itemBuilder: (item) {
          scene.itemBuilds++;
          return GestureDetector(
            onTap: () => scene.taps++,
            child: ColoredBox(
                key: Key('tile_${item.identifier}'), color: Colors.red),
          );
        },
      );
    },
  );
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    home: Scaffold(
      body: ancestorVerticalDrag
          ? GestureDetector(onVerticalDragUpdate: (_) {}, child: carousel)
          : carousel,
    ),
  ));
  await tester.pumpAndSettle();
  if (editing) {
    controller.isEditing = true;
    await tester.pumpAndSettle();
  }
  return scene;
}
