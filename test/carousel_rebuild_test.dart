import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wave PV, stage e: paging the carousel MOVES the grid instead of rebuilding it.
///
/// Zmierzone przed zmianą (sonda na kadrze telefonu 384×832, 3 sekcje × 8
/// kafelków 6×3): pięć klatek gestu poziomego to **5 wywołań `dashboardBuilder`
/// i 120 wywołań `itemBuilder`** (24 na klatkę, przy 24 kafelkach w drzewie),
/// a `Element` siatki i `Scrollable` PRZEŻYWAŁY gest — czyli nic się nie
/// inflatowało, ta praca była czystym marnotrawstwem. Na telefonie faza `swipe`
/// miała `build p90` **14,9 ms** i **54,5 %** janky, co odpaliło warunek D-PV-3.
///
/// Scena mirroruje kokpit aplikacji (`cockpit_grid.dart`): 20 slotów, separatory
/// 6 i 13, `showHeader: false`, kropki włączone, krok 2 sekcji na tablecie.
void main() {
  const surface = Size(384, 832);
  const virtualColumns = VirtualColumnsConfig.visible(
    disabledColumns: [6, 13],
    disabledColumnWidth: 0.03,
  );
  const config = MobileCarouselConfig(
    visibleSectionsOnMobile: 1,
    visibleSectionsOnTablet: 2,
    sectionStepOnTablet: 2,
    showHeader: false,
  );

  late int dashboardBuilderCalls;
  late int itemBuilderCalls;
  late int tileMounts;

  setUp(() {
    dashboardBuilderCalls = 0;
    itemBuilderCalls = 0;
    tileMounts = 0;
  });

  List<DashboardItem> items() => <DashboardItem>[
        for (var section = 0; section < 3; section++)
          for (var row = 0; row < 8; row++)
            DashboardItem(
              identifier: 'i${section}_$row',
              width: 6,
              height: 3,
              startX: section * 7,
              startY: row * 3,
            ),
      ];

  /// Karuzela w konfiguracji kokpitu. `dashboardBuilder` jest tworzony RAZ na
  /// `pumpWidget` — tak jak u konsumenta, który nie przebudowuje się sam od
  /// siebie; jego tożsamość jest częścią klucza cache'u siatki.
  Future<DashboardItemController<DashboardItem>> pumpCarousel(
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = DashboardItemController<DashboardItem>(items: items());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MobileDashboardWrapper<DashboardItem>(
          dashboardItemController: controller,
          slotCount: 20,
          columnsPerPage: 6,
          virtualColumnsConfig: virtualColumns,
          mobileConfig: config,
          dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) {
            dashboardBuilderCalls++;
            return Dashboard<DashboardItem>(
              dashboardItemController: ctrl,
              slotCount: slotCount,
              slotAspectRatio: 1,
              virtualColumnsConfig: virtualColumns,
              padding: const EdgeInsets.all(2),
              horizontalSpace: 4,
              verticalSpace: 4,
              animateEverytime: false,
              itemBuilder: (item) {
                itemBuilderCalls++;
                return _CarouselTile(
                  id: item.identifier,
                  onMount: () => tileMounts++,
                );
              },
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return controller;
  }

  Element gridElement(WidgetTester tester) =>
      find.byType(Dashboard<DashboardItem>).evaluate().single;

  Element scrollableElement(WidgetTester tester) =>
      find.byType(Scrollable).evaluate().single;

  double gridOffset(WidgetTester tester) =>
      tester.getTopLeft(find.byType(Dashboard<DashboardItem>)).dx;

  testWidgets(
      'T-PV4-01 · gest poziomy nie woła itemBuildera i nie rusza elementu siatki',
      (WidgetTester tester) async {
    await pumpCarousel(tester);

    final grid = gridElement(tester);
    final scrollable = scrollableElement(tester);
    final startOffset = gridOffset(tester);

    final gesture = await tester.startGesture(surface.center(Offset.zero));
    // Pierwszy ruch otwiera przeciąganie (próg rozpoznawacza).
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();

    dashboardBuilderCalls = 0;
    itemBuilderCalls = 0;
    tileMounts = 0;

    const frames = 5;
    for (var f = 0; f < frames; f++) {
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
    }

    // Kontrola, że pomiar nie jest próżny: siatka NAPRAWDĘ pojechała w bok.
    expect(gridOffset(tester), lessThan(startOffset),
        reason: 'gest musi przesunąć siatkę (było $startOffset, '
            'jest ${gridOffset(tester)})');

    expect(dashboardBuilderCalls, 0,
        reason: 'klatka gestu nie woła `dashboardBuilder` (zmierzono: '
            '$dashboardBuilderCalls na $frames klatek; przed zmianą 5)');
    expect(itemBuilderCalls, 0,
        reason: 'ani `itemBuilder` (zmierzono: $itemBuilderCalls; przed zmianą '
            '120 na 5 klatek)');
    expect(tileMounts, 0, reason: 'i nic się nie montuje');
    expect(identical(grid, gridElement(tester)), isTrue,
        reason: 'element siatki przeżywa machnięcie');
    expect(identical(scrollable, scrollableElement(tester)), isTrue,
        reason: 'i jej `Scrollable` też');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('T-PV4-02 · animacja strony nie woła itemBuildera',
      (WidgetTester tester) async {
    await pumpCarousel(tester);

    final grid = gridElement(tester);
    final startOffset = gridOffset(tester);

    // Druga kropka = druga strona. Stuknięcie jest jedyną zmianą stanu; potem
    // biegnie 300 ms animacji.
    final dots = find.descendant(
      of: find.byType(MobileDashboardWrapper<DashboardItem>),
      matching: find.byType(AnimatedContainer),
    );
    // Kadr telefonu (384 px < `mobileBreakpoint`) pokazuje JEDNĄ sekcję, więc
    // trzy sekcje to trzy strony i trzy kropki.
    expect(dots, findsNWidgets(3), reason: 'trzy sekcje po jednej na stronę');

    dashboardBuilderCalls = 0;
    itemBuilderCalls = 0;
    tileMounts = 0;

    await tester.tap(dots.at(1));
    await tester.pumpAndSettle();

    // Kontrola próżności: strona naprawdę się zmieniła.
    expect(gridOffset(tester), lessThan(startOffset),
        reason: 'animacja musi przesunąć siatkę na drugą stronę');

    // Zmiana strony przebudowuje kropki (jeden `setState`), ale siatka przychodzi
    // z cache'u: `dashboardBuilder` nie jest wołany ANI RAZ, choć animacja ma
    // 300 ms i kilkanaście klatek. Przed zmianą każda klatka animacji wołała
    // builder i cały `itemBuilder` siatki.
    expect(dashboardBuilderCalls, 0,
        reason: 'animacja strony nie woła `dashboardBuilder` '
            '(zmierzono: $dashboardBuilderCalls)');
    expect(itemBuilderCalls, 0,
        reason: 'ani `itemBuilder` (zmierzono: $itemBuilderCalls)');
    expect(tileMounts, 0, reason: 'i nic się nie montuje');
    expect(identical(grid, gridElement(tester)), isTrue,
        reason: 'element siatki przeżywa zmianę strony');
  });

  testWidgets(
      'T-PV4-02b · powiadomienie kontrolera NADAL woła dashboardBuilder',
      (WidgetTester tester) async {
    final controller = await pumpCarousel(tester);

    dashboardBuilderCalls = 0;

    // Druga strona reguły cache'u: konsument ma prawo CZYTAĆ stan kontrolera
    // w swoim builderze (`room_details_view.dart` zdejmuje w nim tryb edycji,
    // co pinuje `T-K1-03b`), więc powiadomienie musi go dosięgnąć. Cache jest
    // bezpieczny właśnie dlatego, że machnięcie nie powiadamia niczego.
    controller.isEditing = true;
    await tester.pumpAndSettle();

    expect(dashboardBuilderCalls, greaterThan(0),
        reason: 'powiadomienie kontrolera odbudowuje siatkę '
            '(zmierzono: $dashboardBuilderCalls)');
  });
}

class _CarouselTile extends StatefulWidget {
  const _CarouselTile({required this.id, required this.onMount});

  final String id;
  final VoidCallback onMount;

  @override
  State<_CarouselTile> createState() => _CarouselTileState();
}

class _CarouselTileState extends State<_CarouselTile> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) =>
      Container(key: ValueKey('tile_${widget.id}'), color: Colors.teal);
}
