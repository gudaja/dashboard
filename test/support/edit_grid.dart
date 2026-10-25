import 'dart:async';

import 'package:dashboard/dashboard.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Grid and gesture helpers shared by the edit-mode gesture tests.
///
/// The grid is 600 px wide with 100 px slots (6 columns, no padding, the
/// default 4 px spacing), so one slot of movement is 100 px.
const double slot = 100;

/// Drags from [from] by [by] in [steps] moves, the way a finger does.
///
/// `_onMoveUpdate` is throttled by the WALL clock (16 ms,
/// `dashboard_stack.dart`) and a test runs faster than a frame: without a real
/// wait between moves every update after the first is dropped and the gesture
/// does nothing.
Future<void> dragInSteps(
  WidgetTester tester,
  Offset from,
  Offset by, {
  int steps = 5,
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final gesture = await tester.startGesture(from, kind: kind);
  await tester.pump();
  await moveInSteps(tester, gesture, by, steps: steps);
  await _wallClockFrame(tester);
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Moves a [gesture] that is already down by [by] in [steps] moves, with the
/// same real-time wait as [dragInSteps]; the pointer stays down.
Future<void> moveInSteps(
  WidgetTester tester,
  TestGesture gesture,
  Offset by, {
  int steps = 5,
}) async {
  for (var i = 0; i < steps; i++) {
    await _wallClockFrame(tester);
    await gesture.moveBy(by / steps.toDouble());
    await tester.pump();
  }
}

Future<void> _wallClockFrame(WidgetTester tester) => tester
    .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));

/// Mounts a 600x600 grid over a [RecordingDelegate] and switches edit mode on.
Future<(DashboardItemController<DashboardItem>, RecordingDelegate)>
    pumpEditGrid(
  WidgetTester tester,
  List<DashboardItem> items, {
  int slotCount = 6,
  VirtualColumnsConfig? virtualColumnsConfig,
  EditModeSettings? editModeSettings,
}) async {
  tester.view.physicalSize = const Size(600, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final delegate = RecordingDelegate(items);
  final controller = DashboardItemController<DashboardItem>.withDelegate(
      itemStorageDelegate: delegate);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Dashboard<DashboardItem>(
        dashboardItemController: controller,
        slotCount: slotCount,
        slotHeight: slot,
        slideToTop: false,
        shrinkToPlace: false,
        virtualColumnsConfig: virtualColumnsConfig,
        editModeSettings:
            editModeSettings ?? EditModeSettings(resizeCursorSide: 20),
        itemBuilder: (item) => ColoredBox(
            key: ValueKey('tile_${item.identifier}'), color: Colors.red),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  controller.isEditing = true;
  await tester.pumpAndSettle();
  return (controller, delegate);
}

Finder tile(String id) => find.byKey(ValueKey('tile_$id'));

/// `startX,startY wxh` of [id] as the controller holds it.
String layoutOf(DashboardItemController<DashboardItem> controller, String id) {
  final l = controller.allItems
      .firstWhere((item) => item.identifier == id)
      .layoutData;
  return '${l.startX},${l.startY} ${l.width}x${l.height}';
}

/// Storage delegate that serves a fixed list and records every write.
class RecordingDelegate extends DashboardItemStorageDelegate<DashboardItem> {
  RecordingDelegate(this.source);

  final List<DashboardItem> source;

  /// `id startX,startY wxh` of every item passed to `onItemsUpdated`.
  final List<String> updated = [];
  final List<List<String>> added = [];
  final List<List<String>> deleted = [];

  @override
  bool get cacheItems => false;

  @override
  bool get layoutsBySlotCount => false;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) => source;

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {
    added.add(items.map((e) => e.identifier).toList());
  }

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {
    deleted.add(items.map((e) => e.identifier).toList());
  }

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {
    for (final item in items) {
      final l = item.layoutData;
      updated.add('${item.identifier} '
          '${l.startX},${l.startY} ${l.width}x${l.height}');
    }
  }
}
