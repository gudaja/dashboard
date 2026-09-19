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

  // =========================================================================
  // Luki pokrycia zgłoszone przez fazę C2 — KOMPLETNOŚĆ klucza memoizacji.
  //
  // Obie mutacje ZWĘŻAJĄCE klucz przechodziły suitę forka (89), a M-e3 także
  // CAŁĄ suitę aplikacji (5543): `T-PV4-01` i `-02` liczą wywołania na klatkę
  // GESTU, a tam builder nie jest wołany ani w wersji poprawnej, ani w zepsutej
  // (notyfikator offsetu i memoizacja dowożą ten sam skutek — tabela prawdy
  // fazy C2: `T-PV4-01` czerwienieje tylko, gdy zepsute są OBA mechanizmy).
  // Te dwa testy mierzą drugą połowę kontraktu: „builder wołany RAZ na zmianę
  // parametrów" — i dlatego ROZDZIELAJĄ to, czego tabela prawdy nie rozdziela:
  // stoją na przebudowie rodzica, nie na geście, więc nie ma w nich notyfikatora
  // offsetu, który mógłby zamaskować zwężony klucz.
  // =========================================================================

  testWidgets(
      'T-PV4-05 · zmiana `slotCount` unieważnia memo, a geometria siatki podąża',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = DashboardItemController<DashboardItem>(items: items());

    // Builder STABILNY: jedno domknięcie na oba przebiegi. Bez tego samo jego
    // odtworzenie unieważniałoby memo i test mierzyłby tożsamość buildera
    // zamiast `slotCount`. (Pułapka zmierzona w fazie C2: tear-off METODY
    // instancyjnej jest `==`, ale nie musi być `identical`, a klucz memo używa
    // `identical` — konsument z „stałym" builderem może więc cache tracić.)
    // Deklaracja funkcji LOKALNEJ wiąże jedno domknięcie, a dowodem, że jest
    // stabilne, jest asercja „cache trafia" po przebudowie bez zmian niżej.
    Widget stableBuilder(
      DashboardItemController<DashboardItem> ctrl,
      int slotCount,
      int startColumn,
      bool isMobile,
    ) {
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
    }

    Widget tree(int slotCount) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: surface.width,
              height: surface.height,
              child: MobileDashboardWrapper<DashboardItem>(
                dashboardItemController: controller,
                slotCount: slotCount,
                columnsPerPage: 6,
                virtualColumnsConfig: virtualColumns,
                mobileConfig: config,
                dashboardBuilder: stableBuilder,
              ),
            ),
          ),
        );

    await tester.pumpWidget(tree(20));
    await tester.pumpAndSettle();

    double tileWidth() =>
        tester.getRect(find.byKey(const ValueKey('tile_i0_0'))).width;
    final widthAt20 = tileWidth();

    // Kontrola, że builder NAPRAWDĘ jest stabilny: przebudowa rodzica bez żadnej
    // zmiany trafia w cache.
    dashboardBuilderCalls = 0;
    await tester.pumpWidget(tree(20));
    await tester.pumpAndSettle();
    expect(dashboardBuilderCalls, 0,
        reason: 'ten sam builder i ten sam `slotCount` = cache trafia '
            '(zmierzono: $dashboardBuilderCalls)');

    dashboardBuilderCalls = 0;
    tileMounts = 0;
    await tester.pumpWidget(tree(14));
    await tester.pumpAndSettle();

    // ZMIERZONE (sonda S-e4 fazy C2, kadr 384×832): szerokość kafelka 369,76 →
    // 371,64 px, `dashboardBuilder` wołany RAZ. Pod mutacją M-e2 (klucz bez
    // `slotCount`) siatka ZOSTAJE na 20 slotach w węższym pudełku, które
    // arytmetyka wrappera policzyła już dla 14 — kafelek dostaje 247,09 px,
    // a `dashboardBuilder` nie jest wołany ani razu.
    expect(dashboardBuilderCalls, 1,
        reason: 'zmiana `slotCount` odbudowuje siatkę DOKŁADNIE raz '
            '(zmierzono: $dashboardBuilderCalls)');
    expect(tileMounts, 0,
        reason: 'i nie remountuje kafelków (zmierzono: $tileMounts)');
    expect(tileWidth(), closeTo(widthAt20, 5),
        reason:
            'kafelek 6 slotów szerokości zachowuje swój udział w sekcji, bo '
            'siatka policzyła geometrię dla 14 slotów (zmierzono: $widthAt20 → '
            '${tileWidth()}; pod M-e2 wychodzi ~2/3 tej wartości)');
  });

  testWidgets(
      'T-PV4-06 · nowe domknięcie `dashboardBuilder` unieważnia memo i jest '
      'WIDOCZNE w drzewie', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = DashboardItemController<DashboardItem>(items: items());

    // Każde wywołanie `tree` tworzy NOWE domknięcie, które wpieka `marker` —
    // dokładnie tak dociera do kokpitu zmiana motywu: `CockpitGrid` buduje
    // `dashboardBuilder` (i w nim `itemBuilder`) w swoim `build`, więc tożsamość
    // buildera jest JEDYNĄ drogą, którą zamontowany kafelek dowiaduje się
    // o nowej treści. Mutacja M-e3 (klucz bez tożsamości buildera) przechodziła
    // suitę forka ORAZ całą suitę aplikacji: kafelki zamarzłyby z treścią
    // z chwili budowy i nikt by tego nie zauważył.
    Widget tree(String marker) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: surface.width,
              height: surface.height,
              child: MobileDashboardWrapper<DashboardItem>(
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
                      return Text('$marker:${item.identifier}');
                    },
                  );
                },
              ),
            ),
          ),
        );

    await tester.pumpWidget(tree('A'));
    await tester.pumpAndSettle();
    expect(find.text('A:i0_0'), findsOneWidget);

    dashboardBuilderCalls = 0;
    itemBuilderCalls = 0;
    await tester.pumpWidget(tree('B'));
    await tester.pumpAndSettle();

    expect(dashboardBuilderCalls, 1,
        reason: 'nowe domknięcie odbudowuje siatkę DOKŁADNIE raz '
            '(zmierzono: $dashboardBuilderCalls; pod M-e3 zero)');
    expect(find.text('B:i0_0'), findsOneWidget,
        reason: 'i to, co ono buduje, JEST w drzewie — licznik sam nie '
            'wystarcza, bo mierzy pracę, a nie jej skutek');
    expect(find.text('A:i0_0'), findsNothing, reason: 'a stara treść znika');
    expect(itemBuilderCalls, greaterThan(0),
        reason: 'nowy `itemBuilder` został zawołany (zmierzono: '
            '$itemBuilderCalls)');
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
