import 'dart:async';

import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage K1: controller/grid lifecycle and delegate cache invalidation.
///
/// Everything here goes through the public API of the package only, the same
/// way the consuming application uses it.
void main() {
  testWidgets('T-K1-01 · po odmontowaniu siatki kontroler nie trzyma jej layoutu',
      (WidgetTester tester) async {
    final controller = DashboardItemController<DashboardItem>(
      items: [DashboardItem(identifier: 'a', width: 1, height: 1)],
    );

    await tester.pumpWidget(_grid(controller, key: const ValueKey('grid')));
    await tester.pumpAndSettle();

    controller.isEditing = true;
    await tester.pumpAndSettle();
    expect(controller.isEditing, isTrue);

    await tester.pumpWidget(_empty());
    await tester.pumpAndSettle();

    // Kontroler nie czyta już stanu osieroconej siatki...
    expect(controller.isEditing, isFalse);

    // ...i nie kieruje do niej zapisów.
    expect(
      () => controller.add(DashboardItem(identifier: 'b', width: 1, height: 1)),
      throwsA(isA<Exception>().having(
          (e) => e.toString(), 'komunikat', contains('Not Attached'))),
    );
  });

  testWidgets('T-K1-02 · isEditing bez zamontowanej siatki nie rzuca NPE',
      (WidgetTester tester) async {
    // Kontroler, który nigdy nie widział siatki.
    final fresh = DashboardItemController<DashboardItem>(items: []);
    expect(() => fresh.isEditing = true, returnsNormally);
    expect(fresh.isEditing, isFalse);

    // Kontroler po odmontowaniu siatki — stan, który wprowadza detach.
    final used = DashboardItemController<DashboardItem>(
      items: [DashboardItem(identifier: 'a', width: 1, height: 1)],
    );
    await tester.pumpWidget(_grid(used, key: const ValueKey('grid')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_empty());
    await tester.pumpAndSettle();

    expect(() => used.isEditing = true, returnsNormally);
    expect(used.isEditing, isFalse);
  });

  testWidgets('T-K1-03 · zmiana isEditing powiadamia słuchaczy kontrolera',
      (WidgetTester tester) async {
    final controller = DashboardItemController<DashboardItem>(
      items: [DashboardItem(identifier: 'a', width: 1, height: 1)],
    );

    await tester.pumpWidget(_grid(controller, key: const ValueKey('grid')));
    await tester.pumpAndSettle();

    var notifications = 0;
    void listener() => notifications++;
    controller.addListener(listener);
    addTearDown(() => controller.removeListener(listener));

    controller.isEditing = true;
    expect(notifications, 1);

    // Ta sama wartość — bez powiadomienia.
    controller.isEditing = true;
    expect(notifications, 1);

    controller.isEditing = false;
    expect(notifications, 2);

    await tester.pumpAndSettle();
  });

  testWidgets(
      'T-K1-03b · zdjęcie isEditing w builderze siatki mobilnej nie wywraca ramki',
      (WidgetTester tester) async {
    // Wzorzec z aplikacji (room_details_view.dart:226): dashboardBuilder zdejmuje
    // tryb edycji PODCZAS builda, a builder ten jest wołany wewnątrz
    // ListenableBuilder-a nasłuchującego tego samego kontrolera. Powiadomienie
    // z T-K1-03 trafia więc w trwający build.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = DashboardItemController<DashboardItem>(
      items: [DashboardItem(identifier: 'a', width: 1, height: 1)],
    );

    // Strażnik przed testem-atrapą: musimy naprawdę trafić w tę gałąź.
    var editingSeenInBuild = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MobileDashboardWrapper<DashboardItem>(
          dashboardItemController: controller,
          slotCount: 6,
          dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) {
            if (isMobile && ctrl.isEditing) {
              editingSeenInBuild = true;
              ctrl.isEditing = false;
            }
            return Dashboard<DashboardItem>(
              dashboardItemController: ctrl,
              slotCount: slotCount,
              slotHeight: 40,
              itemBuilder: (item) =>
                  Container(key: Key('tile_${item.identifier}')),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    controller.isEditing = true;
    await tester.pumpAndSettle();

    expect(editingSeenInBuild, isTrue);
    expect(tester.takeException(), isNull);
    expect(controller.isEditing, isFalse);
    expect(find.byKey(const Key('tile_a')), findsOneWidget);
  });

  testWidgets(
      'T-K1-04 · unieważnienie cache delegata wymusza ponowne getAllItems',
      (WidgetTester tester) async {
    final delegate = _RecordingStorageDelegate()..source = ['a'];

    await tester.pumpWidget(_grid(_withDelegate(delegate),
        key: const ValueKey('g1'), slotCount: 4));
    await tester.pumpAndSettle();

    expect(delegate.getAllItemsCalls, [4]);
    expect(find.byKey(const Key('tile_a')), findsOneWidget);

    // Źródło zmienia się poza siatką (inny ekran, inna siatka).
    delegate.source = ['a', 'b'];

    // Samo przemontowanie nie wystarcza: dopóki wpis dla slotCount 4 jest
    // w cache, getAllItems nie jest w ogóle wołane.
    await tester.pumpWidget(_empty());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_grid(_withDelegate(delegate),
        key: const ValueKey('g2'), slotCount: 4));
    await tester.pumpAndSettle();

    expect(delegate.getAllItemsCalls, [4]);
    expect(find.byKey(const Key('tile_b')), findsNothing);

    // Unieważnienie zdejmuje wpis — kolejny odczyt idzie do źródła.
    delegate.invalidateCache(4);

    await tester.pumpWidget(_empty());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_grid(_withDelegate(delegate),
        key: const ValueKey('g3'), slotCount: 4));
    await tester.pumpAndSettle();

    expect(delegate.getAllItemsCalls, [4, 4]);
    expect(find.byKey(const Key('tile_b')), findsOneWidget);
  });

  testWidgets('T-K1-05 · unieważnienie jednego slotCount nie czyści pozostałych',
      (WidgetTester tester) async {
    final delegate = _RecordingStorageDelegate()..source = ['a'];

    await tester.pumpWidget(_grid(_withDelegate(delegate),
        key: const ValueKey('g4'), slotCount: 4));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_empty());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_grid(_withDelegate(delegate),
        key: const ValueKey('g6'), slotCount: 6));
    await tester.pumpAndSettle();

    expect(delegate.getAllItemsCalls, [4, 6]);
    expect(delegate.itemsFor(4), isNotNull);
    expect(delegate.itemsFor(6), isNotNull);

    delegate.invalidateCache(4);

    expect(delegate.itemsFor(4), isNull);
    expect(delegate.itemsFor(6), isNotNull);

    // Bez argumentu — cały cache.
    delegate.invalidateCache();
    expect(delegate.itemsFor(6), isNull);
  });

  testWidgets(
      'T-K1-06 · po odmontowaniu i zamontowaniu nowej siatki zapisy idą do nowej',
      (WidgetTester tester) async {
    final delegate = _RecordingStorageDelegate()..source = ['a'];
    final controller = _withDelegate(delegate);

    await tester.pumpWidget(
        _grid(controller, key: const ValueKey('stara'), slotCount: 4));
    await tester.pumpAndSettle();

    // Podmiana siatki w jednej klatce: nowa montuje się ZANIM stara zostanie
    // odmontowana, więc detach musi rozpoznać, która siatka odchodzi.
    await tester.pumpWidget(
        _grid(controller, key: const ValueKey('nowa'), slotCount: 6));
    await tester.pumpAndSettle();

    delegate.onItemsAddedCalls.clear();
    controller.add(DashboardItem(identifier: 'nowy', width: 1, height: 1));
    await tester.pumpAndSettle();

    expect(delegate.onItemsAddedCalls, [6]);
    expect(find.byKey(const Key('tile_nowy')), findsOneWidget);
  });

  testWidgets('T-K1-07 · odmontowanie siatki NIE wywołuje zapisu',
      (WidgetTester tester) async {
    final delegate = _RecordingStorageDelegate()..source = ['a', 'b'];
    final controller = _withDelegate(delegate);

    await tester.pumpWidget(
        _grid(controller, key: const ValueKey('grid'), slotCount: 4));
    await tester.pumpAndSettle();

    // Obserwacja, nie postulat: mountItems zapisuje po każdym attach.
    // Etap K1 tego nie zmienia — pilnuje tylko, żeby odmontowanie nie dołożyło
    // drugiej ścieżki nadpisania układu.
    final afterMount = List<int>.from(delegate.onItemsUpdatedCalls);

    await tester.pumpWidget(_empty());
    await tester.pumpAndSettle();

    expect(delegate.onItemsUpdatedCalls, afterMount);
    expect(delegate.onItemsAddedCalls, isEmpty);
    expect(delegate.onItemsDeletedCalls, isEmpty);
  });
}

DashboardItemController<DashboardItem> _withDelegate(
        _RecordingStorageDelegate delegate) =>
    DashboardItemController<DashboardItem>.withDelegate(
        itemStorageDelegate: delegate);

Widget _grid(
  DashboardItemController<DashboardItem> controller, {
  required Key key,
  int slotCount = 4,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Dashboard<DashboardItem>(
        key: key,
        dashboardItemController: controller,
        slotCount: slotCount,
        slotHeight: 40,
        itemBuilder: (item) => Container(key: Key('tile_${item.identifier}')),
      ),
    ),
  );
}

Widget _empty() => const MaterialApp(home: Scaffold(body: SizedBox()));

/// Storage delegate that records every call the package makes on it, and lets
/// the test change the source of truth between mounts.
class _RecordingStorageDelegate
    extends DashboardItemStorageDelegate<DashboardItem> {
  /// Identifiers the "storage" currently holds.
  List<String> source = const [];

  final List<int> getAllItemsCalls = [];
  final List<int> onItemsAddedCalls = [];
  final List<int> onItemsUpdatedCalls = [];
  final List<int> onItemsDeletedCalls = [];

  @override
  bool get cacheItems => true;

  @override
  bool get layoutsBySlotCount => true;

  @override
  FutureOr<List<DashboardItem>> getAllItems(int slotCount) {
    getAllItemsCalls.add(slotCount);
    return source
        .map((e) => DashboardItem(identifier: e, width: 1, height: 1))
        .toList();
  }

  @override
  FutureOr<void> onItemsAdded(List<DashboardItem> items, int slotCount) {
    onItemsAddedCalls.add(slotCount);
  }

  @override
  FutureOr<void> onItemsDeleted(List<DashboardItem> items, int slotCount) {
    onItemsDeletedCalls.add(slotCount);
  }

  @override
  FutureOr<void> onItemsUpdated(List<DashboardItem> items, int slotCount) {
    onItemsUpdatedCalls.add(slotCount);
  }
}
