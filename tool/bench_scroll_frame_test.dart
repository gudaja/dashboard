// Measures one frame of scrolling a grid: how many widgets rebuild and how
// long the frame takes. Not part of the test suite (`flutter test` only scans
// `test/`); run it with:
//
//   flutter test tool/bench_scroll_frame_test.dart
//
// The rebuild counts come from `debugOnRebuildDirtyWidget` and do not depend
// on the build mode. The times are from a debug-mode test binding (asserts on,
// no rasterization), so they only compare two versions of the package on the
// same machine; they are not frame times of a release build.
// ignore_for_file: avoid_print
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _frames = 200;
const _step = 4.0;

void main() {
  for (final (name, size, slotCount, items) in [
    ('cockpit, phone, 30 items', const Size(390, 700), 6, 30),
    ('desktop, 600 items', const Size(1400, 900), 24, 600),
  ]) {
    for (final (editing, sliver) in [
      (false, false),
      (true, false),
      (false, true),
    ]) {
      final label = '$name${editing ? ', edit mode' : ''}'
          '${sliver ? ', SliverDashboard' : ''}';
      testWidgets(label, (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final controller = DashboardItemController<DashboardItem>(items: [
          for (var i = 0; i < items; i++)
            DashboardItem(
                identifier: 'i$i',
                width: 1,
                height: 1,
                // Every other slot, so the background shows between items.
                startX: (i * 2) % slotCount,
                startY: (i * 2) ~/ slotCount),
        ]);
        Widget itemBuilder(DashboardItem item) =>
            const ColoredBox(color: Colors.teal);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: sliver
                ? CustomScrollView(slivers: [
                    const SliverAppBar(pinned: true, title: Text('band')),
                    SliverDashboard<DashboardItem>(
                      dashboardItemController: controller,
                      slotCount: slotCount,
                      slideToTop: false,
                      itemBuilder: itemBuilder,
                    ),
                  ])
                : Dashboard<DashboardItem>(
                    dashboardItemController: controller,
                    slotCount: slotCount,
                    slideToTop: false,
                    editModeSettings:
                        EditModeSettings(scrollWhileEditing: true),
                    itemBuilder: itemBuilder,
                  ),
          ),
        ));
        await tester.pumpAndSettle();
        if (editing) {
          controller.isEditing = true;
          await tester.pumpAndSettle();
        }

        final position =
            tester.state<ScrollableState>(find.byType(Scrollable)).position;
        final counts = <String, int>{};
        var rebuilds = 0;
        final watch = Stopwatch();

        // Warm-up, not counted.
        for (var i = 0; i < 20; i++) {
          position.jumpTo(position.pixels + _step);
          await tester.pump(const Duration(milliseconds: 16));
        }

        debugOnRebuildDirtyWidget = (element, builtOnce) {
          rebuilds++;
          final type = element.widget.runtimeType.toString();
          counts[type] = (counts[type] ?? 0) + 1;
        };
        for (var i = 0; i < _frames; i++) {
          position.jumpTo(position.pixels + _step);
          watch.start();
          await tester.pump(const Duration(milliseconds: 16));
          watch.stop();
        }
        debugOnRebuildDirtyWidget = null;

        final top = (counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(4)
            .map((e) => '${e.key} ${(e.value / _frames).toStringAsFixed(1)}')
            .join(', ');
        print('$label: '
            '${(watch.elapsedMicroseconds / _frames).toStringAsFixed(0)} µs/frame, '
            '${(rebuilds / _frames).toStringAsFixed(1)} rebuilds/frame ($top)');
      });
    }
  }
}
