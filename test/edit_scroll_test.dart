import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/edit_grid.dart';

/// EditModeSettings.scrollWhileEditing: the grid scrolls in edit mode, an item
/// is picked up by a hold (finger) or a move (mouse), and an item dragged to an
/// edge scrolls the grid or flips the carousel section.
///
/// Everything here goes through the public API of the package only.
void main() {
  EditModeSettings scrolling({
    ResizeHandleBuilder? resizeHandleBuilder,
    DeleteHandleBuilder? deleteHandleBuilder,
  }) =>
      EditModeSettings(
        resizeCursorSide: 20,
        scrollWhileEditing: true,
        resizeHandleBuilder: resizeHandleBuilder,
        deleteHandleBuilder: deleteHandleBuilder,
      );

  /// `a` in the middle of a grid twelve rows tall: 1200 px of content in a
  /// 600 px viewport, so the grid scrolls by up to 600 px.
  List<DashboardItem> tall() => [
        DashboardItem(
            identifier: 'a', width: 1, height: 1, startX: 1, startY: 2),
        DashboardItem(
            identifier: 'end', width: 1, height: 1, startX: 5, startY: 11),
      ];

  group('scrollWhileEditing: false', () {
    testWidgets(
        'T-SE-01 · bez flagi przeciągnięcie pustego pola nie przewija, swipe '
        'karuzeli w edycji nic nie robi', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, tall());

      await tester.dragFrom(const Offset(450, 450), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(_pixels(tester), 0);
      expect(layoutOf(controller, 'a'), '1,2 1x1');

      await tester.pumpWidget(const SizedBox());
      final carousel = await _pumpCarousel(tester,
          settings: EditModeSettings(), config: const MobileCarouselConfig());
      await tester.timedDragFrom(
          const Offset(300, 400), const Offset(-200, 0), _slow);
      await tester.pumpAndSettle();

      expect(find.text('Sekcja 1 z 4'), findsOneWidget);
      expect(layoutOf(carousel, 's0'), '1,0 1x1');
    });
  });

  group('scrollWhileEditing: true', () {
    testWidgets('T-SE-02 · palec na pustym polu przewija, układ bez zmian',
        (WidgetTester tester) async {
      final (controller, delegate) =
          await pumpEditGrid(tester, tall(), editModeSettings: scrolling());

      await tester.dragFrom(const Offset(450, 450), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(_pixels(tester), greaterThan(200));
      expect(layoutOf(controller, 'a'), '1,2 1x1');
      expect(delegate.updated, isEmpty);
    });

    testWidgets(
        'T-SE-03 · szybki ruch palcem zaczęty na kafelku przewija, kafelek '
        'stoi', (WidgetTester tester) async {
      final (controller, delegate) =
          await pumpEditGrid(tester, tall(), editModeSettings: scrolling());
      final lifted = <String?>[];
      controller.liftedItem.addListener(() {
        lifted.add(controller.liftedItem.value);
      });

      await tester.dragFrom(
          tester.getRect(tile('a')).center, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(_pixels(tester), greaterThan(100));
      expect(layoutOf(controller, 'a'), '1,2 1x1');
      expect(delegate.updated, isEmpty);
      expect(lifted, isEmpty, reason: 'never picked up');
    });

    testWidgets(
        'T-SE-04 · przytrzymanie palca chwyta kafelek, potem ruch go '
        'przesuwa, a siatka stoi', (WidgetTester tester) async {
      final (controller, _) =
          await pumpEditGrid(tester, tall(), editModeSettings: scrolling());

      final gesture = await tester.startGesture(
          tester.getRect(tile('a')).center,
          kind: PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.liftedItem.value, isNull, reason: 'not yet');
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.liftedItem.value, 'a');

      await moveInSteps(tester, gesture, const Offset(2 * slot, slot));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(layoutOf(controller, 'a'), '3,3 1x1');
      expect(_pixels(tester), 0);
      expect(controller.liftedItem.value, isNull);
    });

    testWidgets(
        'T-SE-05 · mysz: poziomy ruch po kafelku w karuzeli przesuwa '
        'kafelek, nie sekcję', (WidgetTester tester) async {
      final controller = await _pumpCarousel(tester);
      final s1 = tester.getRect(find.byKey(const Key('tile_s0')));

      await dragInSteps(tester, s1.center, Offset(-s1.width - 4, 0),
          kind: PointerDeviceKind.mouse);

      expect(find.text('Sekcja 1 z 4'), findsOneWidget);
      expect(layoutOf(controller, 's0'), '0,0 1x1');
    });

    testWidgets(
        'T-SE-05a · palec: swipe po pustym polu w edycji zmienia sekcję',
        (WidgetTester tester) async {
      await _pumpCarousel(tester);

      await tester.timedDragFrom(
          const Offset(300, 400), const Offset(-200, 0), _slow);
      await tester.pumpAndSettle();

      expect(find.text('Sekcja 2 z 4'), findsOneWidget);
    });

    testWidgets(
        'T-SE-05b · mysz: kliknięcie przycisku usuwania na kafelku nadal '
        'usuwa kafelek', (WidgetTester tester) async {
      final (controller, delegate) = await pumpEditGrid(
        tester,
        tall(),
        editModeSettings: scrolling(
          deleteHandleBuilder: (context, item, isEditing, onDelete) =>
              GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDelete,
            child: SizedBox(
                key: ValueKey('delete_${item.identifier}'),
                width: 28,
                height: 28),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('delete_a')),
          kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(controller.items, ['end']);
      expect(delegate.deleted, [
        ['a']
      ]);
    });

    testWidgets('T-SE-06 · kółko myszy przewija w edycji',
        (WidgetTester tester) async {
      await pumpEditGrid(tester, tall(), editModeSettings: scrolling());

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(450, 450)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 250)));
      await tester.pumpAndSettle();

      expect(_pixels(tester), 250);
    });

    testWidgets(
        'T-SE-07 · kafelek trzymany w dolnej strefie przewija siatkę sam, '
        'do jednego wiersza za końcem, i zostaje pod kursorem',
        (WidgetTester tester) async {
      final (controller, _) =
          await pumpEditGrid(tester, tall(), editModeSettings: scrolling());

      const at = Offset(150, 590);
      final gesture = await tester.startGesture(
          tester.getRect(tile('a')).center,
          kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(at);
      await tester.pump();
      // The first tick of the ticker only takes the time.
      await tester.pump(const Duration(milliseconds: 16));
      final start = _pixels(tester);

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrolled = _pixels(tester) - start;
      expect(scrolled, greaterThan(0));
      expect(scrolled, lessThanOrEqualTo(1200 * 0.160 + 1e-6),
          reason: 'autoScrollMaxSpeed × time');
      expect(tester.getRect(tile('a')).contains(at), isTrue,
          reason: 'the item followed the content without a pointer event');

      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 1200 px of content in 600 px, plus one row.
      expect(_pixels(tester), 600 + slot);
      expect(tester.getRect(tile('a')).contains(at), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.liftedItem.value, isNull);
      expect(layoutOf(controller, 'a'), '1,12 1x1',
          reason: 'dropped on the row past the end, which grows the grid');
      expect(_pixels(tester), 600 + slot,
          reason: 'stays where the drag took it');
    });

    testWidgets('T-SE-08 · ta sama prędkość przy 60 i 120 Hz',
        (WidgetTester tester) async {
      Future<double> scrolledIn(Duration frame, int frames) async {
        await tester.pumpWidget(const SizedBox());
        await pumpEditGrid(tester, tall(), editModeSettings: scrolling());
        final gesture = await tester.startGesture(
            tester.getRect(tile('a')).center,
            kind: PointerDeviceKind.mouse);
        await tester.pump();
        await gesture.moveTo(const Offset(150, 580));
        await tester.pump();
        await tester.pump(frame);
        final start = _pixels(tester);
        for (var i = 0; i < frames; i++) {
          await tester.pump(frame);
        }
        final scrolled = _pixels(tester) - start;
        await gesture.up();
        await tester.pumpAndSettle();
        return scrolled;
      }

      final at60 = await scrolledIn(const Duration(microseconds: 16667), 12);
      final at120 = await scrolledIn(const Duration(microseconds: 8333), 24);

      expect(at60, greaterThan(50));
      expect(at120, moreOrLessEquals(at60, epsilon: 1));
    });

    testWidgets(
        'T-SE-09 · karuzela: kafelek przy prawej krawędzi przechodzi sekcja '
        'po sekcji i ląduje w nowej', (WidgetTester tester) async {
      final controller = await _pumpCarousel(tester);
      final s0 = tester.getRect(find.byKey(const Key('tile_s0')));
      final at = Offset(360, s0.center.dy);

      final gesture =
          await tester.startGesture(s0.center, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(at);
      await tester.pump();

      await _pumpFor(tester, const Duration(milliseconds: 400));
      expect(find.text('Sekcja 1 z 4'), findsOneWidget, reason: 'dwell');
      await _pumpFor(tester, const Duration(milliseconds: 450));
      expect(find.text('Sekcja 2 z 4'), findsOneWidget);
      await _pumpFor(tester, const Duration(milliseconds: 850));
      expect(find.text('Sekcja 3 z 4'), findsOneWidget);
      expect(
          tester.getRect(find.byKey(const Key('tile_s0'))).contains(at), isTrue,
          reason: 'the item stayed under the pointer');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Sekcja 3 z 4'), findsOneWidget, reason: 'page stays');
      expect(layoutOf(controller, 's0'), '17,0 1x1',
          reason: 'the last column of section 3, under the pointer');
    });

    testWidgets(
        'T-SE-10 · uchwyt resize przy dolnej krawędzi: siatka przewija się, '
        'a kafelek rośnie dalej', (WidgetTester tester) async {
      final (controller, _) = await pumpEditGrid(tester, tall(),
          editModeSettings: scrolling(
              resizeHandleBuilder: (context, item, isEditing) => SizedBox(
                  key: ValueKey('resize_${item.identifier}'),
                  width: 28,
                  height: 28)));

      final handle = tester.getRect(find.byKey(const ValueKey('resize_a')));
      // A finger on the handle: no hold needed.
      final gesture = await tester.startGesture(handle.center,
          kind: PointerDeviceKind.touch);
      await tester.pump();
      await moveInSteps(tester, gesture, Offset(0, 590 - handle.center.dy));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await moveInSteps(tester, gesture, Offset.zero, steps: 1);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_pixels(tester), greaterThan(0));
      final height = controller.allItems
          .firstWhere((item) => item.identifier == 'a')
          .layoutData
          .height;
      expect(height, greaterThan(4),
          reason: 'past the 600 px the viewport would allow without scrolling');
    });

    testWidgets(
        'T-SE-11 · kolumny-separatory: po zmianie sekcji kafelek nie ląduje '
        'w kolumnie wyłączonej', (WidgetTester tester) async {
      final controller = await _pumpCarousel(tester,
          slotCount: 20,
          virtualColumnsConfig:
              const VirtualColumnsConfig.visible(disabledColumns: [6, 13]));
      expect(find.text('Sekcja 1 z 3'), findsOneWidget);
      final s0 = tester.getRect(find.byKey(const Key('tile_s0')));

      final gesture =
          await tester.startGesture(s0.center, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(Offset(388, s0.center.dy));
      await tester.pump();
      await _pumpFor(tester, const Duration(milliseconds: 850));
      expect(find.text('Sekcja 2 z 3'), findsOneWidget);

      // Back to the first column of section 2, right after the separator.
      await gesture.moveTo(Offset(20, s0.center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final x = controller.allItems
          .firstWhere((item) => item.identifier == 's0')
          .layoutData
          .startX;
      expect(x, isNot(6));
      expect(x, inInclusiveRange(7, 12));
    });

    testWidgets(
        'T-SE-12 · anulowanie gestu w trakcie autoscrolla zatrzymuje '
        'ticker i zegar zmiany sekcji', (WidgetTester tester) async {
      final (controller, _) =
          await pumpEditGrid(tester, tall(), editModeSettings: scrolling());

      final gesture = await tester.startGesture(
          tester.getRect(tile('a')).center,
          kind: PointerDeviceKind.mouse);
      await tester.pump();
      await gesture.moveTo(const Offset(150, 590));
      await _pumpFor(tester, const Duration(milliseconds: 200));
      expect(_pixels(tester), greaterThan(0));

      await gesture.cancel();
      await tester.pumpAndSettle();
      final after = _pixels(tester);
      await _pumpFor(tester, const Duration(milliseconds: 200));

      expect(_pixels(tester), after);
      expect(controller.liftedItem.value, isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // The carousel's dwell timer too: a pending Timer fails the test.
      await tester.pumpWidget(const SizedBox());
      await _pumpCarousel(tester);
      final s0 = tester.getRect(find.byKey(const Key('tile_s0')));
      final drag =
          await tester.startGesture(s0.center, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await drag.moveTo(Offset(385, s0.center.dy));
      await tester.pump(const Duration(milliseconds: 100));
      await drag.cancel();
      await _pumpFor(tester, const Duration(milliseconds: 800));

      expect(find.text('Sekcja 1 z 4'), findsOneWidget);
    });
  });
}

const _slow = Duration(milliseconds: 800);

double _pixels(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const frame = Duration(milliseconds: 16);
  for (var t = Duration.zero; t < total; t += frame) {
    await tester.pump(frame);
  }
}

/// A phone-wide carousel in edit mode: [slotCount] columns, sections of 6
/// (or split at the disabled columns), and an item `s<n>` in the second
/// column of each section.
Future<DashboardItemController<DashboardItem>> _pumpCarousel(
  WidgetTester tester, {
  EditModeSettings? settings,
  MobileCarouselConfig config =
      const MobileCarouselConfig(swipeWhileEditing: true),
  int slotCount = 24,
  VirtualColumnsConfig? virtualColumnsConfig,
}) async {
  tester.view.physicalSize = const Size(390, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final starts = virtualColumnsConfig == null
      ? [for (var s = 0; s < slotCount ~/ 6; s++) s * 6]
      : [
          0,
          for (final c in virtualColumnsConfig.disabledColumns) c + 1,
        ];
  final controller = DashboardItemController<DashboardItem>(items: [
    for (var s = 0; s < starts.length; s++)
      DashboardItem(
          identifier: 's$s',
          width: 1,
          height: 1,
          startX: starts[s] + 1,
          startY: 0),
  ]);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MobileDashboardWrapper<DashboardItem>(
        dashboardItemController: controller,
        slotCount: slotCount,
        columnsPerPage: 6,
        virtualColumnsConfig: virtualColumnsConfig,
        mobileConfig: config,
        dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) =>
            Dashboard<DashboardItem>(
          dashboardItemController: ctrl,
          slotCount: slotCount,
          slotHeight: 40,
          // The wrapper sizes its pages for a grid padded by 8.
          padding: const EdgeInsets.all(8),
          slideToTop: false,
          shrinkToPlace: false,
          virtualColumnsConfig: virtualColumnsConfig,
          editModeSettings:
              settings ?? EditModeSettings(scrollWhileEditing: true),
          itemBuilder: (item) => Container(key: Key('tile_${item.identifier}')),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  controller.isEditing = true;
  await tester.pumpAndSettle();
  return controller;
}
