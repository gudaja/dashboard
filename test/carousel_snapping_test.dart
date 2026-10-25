import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// MobileCarouselConfig.pageSnapping on a phone: 24 columns cut every 6 into
/// four sections, one visible at a time.
///
/// Everything here goes through the public API of the package only. The items
/// `s0`…`s3` stand in the second column of each section (the first column of
/// the grid has no left spacing, the others do), so the left edge of `s<n>`
/// shows where section n is.
void main() {
  testWidgets(
      'T-SN-01 · domyślnie (pageSnapping: true) przeciągnięcie kończy się na '
      'stronie', (WidgetTester tester) async {
    await tester.pumpWidget(_carousel(const MobileCarouselConfig()));
    await tester.pumpAndSettle();
    final home = _left(tester, 's0');

    // 40% of the width, slowly: past the 30% threshold, no fling.
    await tester.timedDragFrom(
        const Offset(300, 300), const Offset(-156, 0), _slow);
    await tester.pumpAndSettle();

    expect(find.text('Sekcja 2 z 4'), findsOneWidget);
    expect(_left(tester, 's1'), moreOrLessEquals(home, epsilon: 1e-6),
        reason: 'section 2 snapped into place');
  });

  testWidgets(
      'T-SN-02 · pageSnapping: false: siatka zostaje tam, gdzie ją puszczono, '
      'kropki pokazują najbliższą stronę', (WidgetTester tester) async {
    final pages = <int>[];
    await tester.pumpWidget(_carousel(
        const MobileCarouselConfig(pageSnapping: false),
        onPageChanged: pages.add));
    await tester.pumpAndSettle();
    final home = _left(tester, 's0');

    await tester.timedDragFrom(
        const Offset(300, 300), const Offset(-100, 0), _slow);
    await tester.pumpAndSettle();

    expect(_left(tester, 's0'), moreOrLessEquals(home - 100, epsilon: 1e-6),
        reason: 'stays where released');
    expect(find.text('Sekcja 1 z 4'), findsOneWidget, reason: 'nearest page');
    expect(pages, isEmpty);

    // The next drag continues from there; past the middle the nearest page
    // is the second one.
    await tester.timedDragFrom(
        const Offset(300, 300), const Offset(-120, 0), _slow);
    await tester.pumpAndSettle();

    expect(_left(tester, 's0'), moreOrLessEquals(home - 220, epsilon: 1e-6));
    expect(find.text('Sekcja 2 z 4'), findsOneWidget);
    expect(pages, [1]);
  });

  testWidgets(
      'T-SN-03 · pageSnapping: false: kropka nadal przenosi na całą stronę',
      (WidgetTester tester) async {
    await tester
        .pumpWidget(_carousel(const MobileCarouselConfig(pageSnapping: false)));
    await tester.pumpAndSettle();
    final home = _left(tester, 's0');

    await tester.timedDragFrom(
        const Offset(300, 300), const Offset(-100, 0), _slow);
    await tester.pumpAndSettle();

    await tester.tap(_dot(2));
    await tester.pumpAndSettle();

    expect(find.text('Sekcja 3 z 4'), findsOneWidget);
    expect(_left(tester, 's2'), moreOrLessEquals(home, epsilon: 1e-6));
  });
}

const _slow = Duration(milliseconds: 800);

double _left(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(Key('tile_$id'))).left;

/// The [index]-th carousel dot: the only round [AnimatedContainer]s here.
Finder _dot(int index) => find
    .byWidgetPredicate((w) =>
        w is AnimatedContainer &&
        (w.decoration as BoxDecoration?)?.shape == BoxShape.circle)
    .at(index);

Widget _carousel(MobileCarouselConfig config,
    {void Function(int page)? onPageChanged}) {
  final controller = DashboardItemController<DashboardItem>(items: [
    for (var s = 0; s < 4; s++)
      DashboardItem(
          identifier: 's$s', width: 1, height: 1, startX: s * 6 + 1, startY: 0),
  ]);
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 700)),
      child: Center(
        child: SizedBox(
          width: 390,
          height: 700,
          child: Scaffold(
            body: MobileDashboardWrapper<DashboardItem>(
              dashboardItemController: controller,
              slotCount: 24,
              columnsPerPage: 6,
              mobileConfig: config,
              onPageChanged: onPageChanged,
              dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) =>
                  Dashboard<DashboardItem>(
                dashboardItemController: ctrl,
                slotCount: slotCount,
                slotHeight: 40,
                // The wrapper sizes its pages for a grid padded by 8.
                padding: const EdgeInsets.all(8),
                slideToTop: false,
                itemBuilder: (item) =>
                    Container(key: Key('tile_${item.identifier}')),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
