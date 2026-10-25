import 'dart:async';

import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Changes salvaged from the old local branches (`optimalistation3`,
/// `fix_race_condition`) before they were deleted.
///
/// Everything here goes through the public API of the package only.
void main() {
  testWidgets(
      'T-S-01 · podmiana kontrolera z delegatem w tej samej siatce nie rzuca '
      'NPE, tylko pokazuje loadingPlaceholder', (WidgetTester tester) async {
    final first = _withDelegate(_ListStorageDelegate(['a']));

    await tester.pumpWidget(_grid(first, key: const ValueKey('grid')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile_a')), findsOneWidget);

    // Ten sam klucz — Flutter zachowuje stan `Dashboard`, `initState` się nie
    // powtarza, więc nowy kontroler nigdy nie zaczął ładowania i jego
    // `AsyncSnapshot` jest jeszcze `null`.
    final second = _withDelegate(_ListStorageDelegate(['b']));
    await tester.pumpWidget(_grid(second, key: const ValueKey('grid')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('loading')), findsOneWidget);
  });

  group('T-S-02 · szerokość kafelka to suma szerokości jego kolumn', () {
    // Kafelek `wide` zajmuje pierwszy rząd od kolumny `from` do ostatniej, pod
    // nim po jednym kafelku w każdej z tych kolumn. Lewa krawędź `wide` musi
    // się zgadzać z pierwszym, a prawa z ostatnim — także gdy siatka ma
    // padding, bo pozycja „za ostatnią kolumną” nie jest szerokością siatki.
    // Kafelek nie może przechodzić przez kolumnę wyłączoną, więc przy
    // kolumnach wirtualnych wyłączona jest tylko kolumna 0, przed `from`.
    // Wolnych kolumn nie ma, bo siatka dosuwa do nich kafelki.
    for (final (name, from, config) in <(String, int, VirtualColumnsConfig?)>[
      ('bez kolumn wirtualnych', 0, null),
      (
        'z kolumnami wirtualnymi',
        1,
        const VirtualColumnsConfig.visible(
          disabledColumns: [0],
          disabledColumnWidth: 0.1,
        ),
      ),
    ]) {
      testWidgets(name, (WidgetTester tester) async {
        const slotCount = 5;
        final controller = DashboardItemController<DashboardItem>(items: [
          DashboardItem(
              identifier: 'wide',
              width: slotCount - from,
              height: 1,
              startX: from,
              startY: 0),
          for (var x = from; x < slotCount; x++)
            DashboardItem(
                identifier: 'c$x', width: 1, height: 1, startX: x, startY: 1),
        ]);

        await tester.pumpWidget(_grid(
          controller,
          key: const ValueKey('grid'),
          slotCount: slotCount,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          virtualColumnsConfig: config,
        ));
        await tester.pumpAndSettle();

        final wide = tester.getRect(find.byKey(const Key('tile_wide')));
        final first = tester.getRect(find.byKey(Key('tile_c$from')));
        final last = tester.getRect(find.byKey(Key('tile_c${slotCount - 1}')));

        expect(wide.left, moreOrLessEquals(first.left));
        expect(wide.right, moreOrLessEquals(last.right));
      });
    }
  });
}

DashboardItemController<DashboardItem> _withDelegate(
        _ListStorageDelegate delegate) =>
    DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: delegate);

Widget _grid(
  DashboardItemController<DashboardItem> controller, {
  required Key key,
  int slotCount = 4,
  EdgeInsets padding = const EdgeInsets.all(0),
  VirtualColumnsConfig? virtualColumnsConfig,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        child: Dashboard<DashboardItem>(
          key: key,
          dashboardItemController: controller,
          slotCount: slotCount,
          slotHeight: 40,
          padding: padding,
          virtualColumnsConfig: virtualColumnsConfig,
          loadingPlaceholder: const SizedBox(key: Key('loading')),
          itemBuilder: (item) => Container(key: Key('tile_${item.identifier}')),
        ),
      ),
    ),
  );
}

/// Synchronous storage delegate backed by a fixed list of identifiers.
class _ListStorageDelegate extends DashboardItemStorageDelegate<DashboardItem> {
  _ListStorageDelegate(this.source);

  final List<String> source;

  @override
  bool get cacheItems => false;

  @override
  bool get layoutsBySlotCount => false;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) => source
      .map((e) => DashboardItem(identifier: e, width: 1, height: 1))
      .toList();

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {}

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {}
}
