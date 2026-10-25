import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The items move with the scroll as ONE layer: a scroll frame translates the
/// layer and rebuilds no item, and the items are still hit where they are
/// drawn.
///
/// Everything here goes through the public API of the package only.
void main() {
  /// A 600x600 viewport over 20 rows of 100 px, an item every other slot.
  Future<List<String>> pumpTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final taps = <String>[];
    final controller = DashboardItemController<DashboardItem>(items: [
      for (var y = 0; y < 20; y++)
        for (var x = 0; x < 6; x += 2)
          DashboardItem(
              identifier: '$x,$y', width: 1, height: 1, startX: x, startY: y),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dashboard<DashboardItem>(
          dashboardItemController: controller,
          slotCount: 6,
          slotHeight: 100,
          slideToTop: false,
          itemBuilder: (item) => GestureDetector(
            onTap: () => taps.add(item.identifier),
            child: ColoredBox(
                key: ValueKey('tile_${item.identifier}'), color: Colors.teal),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return taps;
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  testWidgets(
      'T-SL-01 · klatka przewijania w obrębie wiersza nie przebudowuje '
      'żadnego kafelka', (WidgetTester tester) async {
    await pumpTall(tester);
    position(tester).jumpTo(210);
    await tester.pump();

    final rebuilt = <String>[];
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      rebuilt.add(element.widget.runtimeType.toString());
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    for (var i = 0; i < 10; i++) {
      position(tester).jumpTo(212 + i * 2.0);
      await tester.pump();
    }
    debugOnRebuildDirtyWidget = null;

    // Per frame: the stack (it listens to the offset for its band), with its
    // own children — the item layer's `Positioned`, same values, no layout —
    // and the AnimatedBuilder that translates the layer. Nothing per item:
    // before the layer every item in the band rebuilt an
    // AnimatedBuilder and a Positioned on every frame.
    expect(rebuilt.where((t) => t == 'AnimatedBuilder').length, 10);
    expect(rebuilt.where((t) => t == 'Positioned').length, 10);
    expect(rebuilt.where((t) => t.startsWith('_DashboardItemWidget')), isEmpty);
  });

  testWidgets(
      'T-SL-02 · po przewinięciu kafelek jest trafiany tam, gdzie jest '
      'narysowany, także na dole treści', (WidgetTester tester) async {
    final taps = await pumpTall(tester);

    position(tester).jumpTo(450);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_2,7')));
    expect(taps, ['2,7']);
    expect(tester.getRect(find.byKey(const ValueKey('tile_2,7'))).top,
        moreOrLessEquals(700 - 450, epsilon: 4));

    position(tester).jumpTo(position(tester).maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_4,19')));
    expect(taps, ['2,7', '4,19']);
  });
}
