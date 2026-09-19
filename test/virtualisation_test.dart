import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wave PV: the vertical band really virtualises, and the slot background is
/// built when the band moves — not on every frame.
///
/// Trzy rzeczy, których ta paczka nie pinowała: czy przewinięcie w ogóle WCIĄGA
/// nowe elementy do drzewa, ile razy na klatkę powstaje warstwa tła slotów i czy
/// cache listy kafelków jest ważny dla zbioru kluczy, z którego powstał.
/// Wszystkie asercje są deterministyczne (liczby widgetów i wywołań builderów),
/// bez progów czasowych — wzorzec `blockly_perf_test.dart` konsumenta.
///
/// Scena jest jedna dla całego pliku: 20 elementów 2×2 jeden pod drugim
/// (4000 px treści) w kadrze 400×500, `slotHeight` 100, `cacheExtend` domyślne
/// 500. Pasmo przy `pixels == 0` to wiersze −5…10, czyli pięć pierwszych
/// elementów; element 0 wyjeżdża z pasma po przewinięciu o 1500 px.
void main() {
  /// Liczniki pracy, którą wykonuje jedna klatka.
  late int itemBuilderCalls;
  late int backgroundCalls;
  late int tileMounts;
  late int tileBuilds;

  /// Elementy sceny — te SAME obiekty, które siatka dostaje w kontrolerze, więc
  /// `layoutData` na nich jest tym, co siatka o nich wie.
  late List<DashboardItem> sceneItems;

  setUp(() {
    itemBuilderCalls = 0;
    backgroundCalls = 0;
    tileMounts = 0;
    tileBuilds = 0;
  });

  const itemCount = 20;
  const slotCount = 4;
  const slotHeight = 100.0;
  const surface = Size(400, 500);

  List<DashboardItem> items() => <DashboardItem>[
        for (var i = 0; i < itemCount; i++)
          DashboardItem(
            identifier: 'i${i.toString().padLeft(2, '0')}',
            width: 2,
            height: 2,
            startX: 0,
            startY: i * 2,
          ),
      ];

  /// Element sceny, który liczy własny montaż i własne przebudowy.
  ///
  /// `initState` odpowiada na pytanie „ile elementów naprawdę weszło do drzewa",
  /// a `build` — „ile razy siatka kazała im się przerysować".
  Widget tile(String id) => _CountingTile(
        id: id,
        onMount: () => tileMounts++,
        onBuild: () => tileBuilds++,
      );

  /// Siatka w jednej, wspólnej konfiguracji.
  ///
  /// `itemBuilder`, `itemStyle` i `editModeSettings` są tworzone RAZ i podawane
  /// jako te same obiekty przy każdym `pumpWidget` — tak, jak zachowuje się
  /// konsument, który ich nie odtwarza w swoim `build`. Bez tego `didUpdateWidget`
  /// słusznie uznałby, że parametry się zmieniły, i test `T-PV2-07` mierzyłby
  /// unieważnienie parametrem, a nie cache kluczy.
  Widget grid({
    required DashboardItemController<DashboardItem> controller,
    SlotBackgroundBuilder<DashboardItem>? background,
    bool withBackground = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: surface.width,
          height: surface.height,
          child: Dashboard<DashboardItem>(
            dashboardItemController: controller,
            slotCount: slotCount,
            slotHeight: slotHeight,
            itemStyle: const ItemStyle(
              color: Colors.transparent,
              type: MaterialType.transparency,
            ),
            editModeSettings: _editModeSettings,
            slotBackgroundBuilder: withBackground
                ? (background ??
                    SlotBackgroundBuilder.withFunction<DashboardItem>(
                        (context, item, x, y, editing) {
                      backgroundCalls++;
                      return Container(key: ValueKey('bg_${x}_$y'));
                    }))
                : null,
            itemBuilder: (item) {
              itemBuilderCalls++;
              return tile(item.identifier);
            },
          ),
        ),
      ),
    );
  }

  Future<DashboardItemController<DashboardItem>> pumpGrid(
    WidgetTester tester, {
    SlotBackgroundBuilder<DashboardItem>? background,
    bool withBackground = true,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    sceneItems = items();
    final controller =
        DashboardItemController<DashboardItem>(items: sceneItems);
    await tester.pumpWidget(grid(
      controller: controller,
      background: background,
      withBackground: withBackground,
    ));
    await tester.pumpAndSettle();
    return controller;
  }

  /// Identyfikatory elementów, które stoją w drzewie.
  List<String> inTree(WidgetTester tester) => tester
      .widgetList<_CountingTile>(find.byType(_CountingTile))
      .map((t) => t.id)
      .toList()
    ..sort();

  ScrollPosition axis(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  /// Przewija o [pixels] w [frames] klatkach i oddaje przyrost [counter]
  /// w każdej z nich.
  ///
  /// `jumpTo` zamiast gestu: to słuchacz offsetu (`dashboard_stack.dart`)
  /// zamienia zmianę `pixels` w klatkę, więc mechanizm jest ten sam, a pomiar
  /// nie zależy od progu rozpoznawacza. Gest przez prawdziwą siatkę pokrywa
  /// benchmark konsumenta (`T-PV1-03`).
  Future<List<int>> scrollFrames(
    WidgetTester tester,
    double pixels,
    int frames,
    int Function() counter,
  ) async {
    final position = axis(tester);
    final step = pixels / frames;
    final samples = <int>[];
    for (var f = 0; f < frames; f++) {
      final before = counter();
      position.jumpTo(position.pixels + step);
      await tester.pump();
      samples.add(counter() - before);
    }
    return samples;
  }

  testWidgets('T-PV2-01 · przewinięcie o pasmo WCIĄGA nowe elementy do drzewa',
      (WidgetTester tester) async {
    await pumpGrid(tester);

    final start = inTree(tester);
    expect(start, isNotEmpty, reason: 'scena musi startować z elementami');
    expect(start.first, 'i00');

    axis(tester).jumpTo(1500);
    await tester.pump();

    final after = inTree(tester);
    // To jest defekt Z1 zapisany jako liczba: do tej fali `_buildStaticWidgets`
    // oddawał cache, którego ścieżka przewijania nigdy nie unieważniała, więc
    // `addWidget` płacił za zbudowanie elementu, a `Stack` dostawał starą listę.
    expect(
      after.where((id) => !start.contains(id)),
      isNotEmpty,
      reason: 'po przewinięciu w drzewie muszą stanąć NOWE elementy '
          '(było: $start, jest: $after)',
    );
    expect(tileMounts, greaterThan(start.length),
        reason: 'i naprawdę się zamontować, a nie tylko zostać zbudowane');
  });

  testWidgets('T-PV2-02 · element, który wyjechał poza pasmo, znika z drzewa',
      (WidgetTester tester) async {
    await pumpGrid(tester);

    expect(inTree(tester), contains('i00'));

    axis(tester).jumpTo(1500);
    await tester.pump();

    // Cache nie zamienia się w wyciek: 1500 px to więcej niż kadr (500) plus
    // `cacheExtend` (500), więc pierwszy element nie ma prawa zostać w drzewie.
    expect(
      inTree(tester),
      isNot(contains('i00')),
      reason: 'element ponad pasmem + cacheExtend musi wyjść z drzewa '
          '(w drzewie: ${inTree(tester)})',
    );
    expect(inTree(tester), isNotEmpty, reason: 'i nie może zabrać reszty');
  });

  testWidgets(
      'T-PV2-03 · klatka przewijania w obrębie pasma: ZERO wywołań '
      'budowniczego tła', (WidgetTester tester) async {
    await pumpGrid(tester);
    expect(backgroundCalls, greaterThan(0),
        reason:
            'montaż musi zbudować tło raz — inaczej nie ma czego nie budować');

    // 10 klatek × 20 px = 200 px, czyli głęboko w paśmie (±500 px).
    final samples = await scrollFrames(tester, 200, 10, () => backgroundCalls);

    // Kontrakt (i) fali PV. Przed zmianą klucz cache'a niósł `pixels`
    // (`dashboard_stack.dart`), więc każda klatka przewijania budowała warstwę
    // od nowa — zmierzone na telefonie jako 56,6 % czasu budowy klatki
    // (7,0 ms z 12,4 ms, 600 slotów na klatkę).
    expect(samples, everyElement(0),
        reason:
            'w obrębie pasma tło nie powstaje ani razu (zmierzono: $samples)');
  });

  testWidgets('T-PV2-04 · zmiana pasma buduje tło dokładnie RAZ',
      (WidgetTester tester) async {
    await pumpGrid(tester);

    // 600 px to jedno wyjście z pasma (`cacheExtend` = 500) i ani jedno więcej:
    // po przebudowie pasmo jest liczone od nowa wokół bieżącej pozycji.
    final samples = await scrollFrames(tester, 600, 10, () => backgroundCalls);
    final rebuilds = samples.where((n) => n > 0).length;

    expect(rebuilds, 1,
        reason: 'jedno wyjście z pasma = jedna przebudowa warstwy '
            '(zmierzono: $samples)');
    expect(samples.reduce((a, b) => a + b), greaterThan(0),
        reason: 'i ta przebudowa naprawdę zbudowała sloty');
  });

  testWidgets(
      'T-PV2-05 · slot, którego builder zwraca null, nie tworzy żadnego widgetu',
      (WidgetTester tester) async {
    // A — siatka BEZ budowniczego tła: punkt odniesienia.
    await pumpGrid(tester, withBackground: false);
    final widgetsWithoutBuilder = tester.allWidgets.length;
    expect(backgroundCalls, 0);

    // B — builder pytany o każdy slot, ale odpowiadający `null`. Dokładnie tak
    // zachowuje się kokpit stojący na tapecie.
    var nullCalls = 0;
    await pumpGrid(
      tester,
      background: SlotBackgroundBuilder.withFunction<DashboardItem>(
        (context, item, x, y, editing) {
          nullCalls++;
          return null;
        },
      ),
    );
    final widgetsWithNullBuilder = tester.allWidgets.length;

    // C — ten sam zbiór slotów, ale każdy rysuje.
    await pumpGrid(tester);
    final widgetsWithBackground = tester.allWidgets.length;
    final slots = backgroundCalls;

    expect(nullCalls, slots,
        reason: 'builder jest pytany o każdy slot w obu wariantach');
    expect(slots, greaterThan(0));
    expect(
      find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('bg_')),
      findsNWidgets(slots),
      reason: 'wariant rysujący ma jeden widget tła na slot',
    );

    // `null` kosztuje DOKŁADNIE jeden widget — puste `SizedBox.shrink` warstwy.
    // Do tej fali kosztował `Positioned` > `RepaintBoundary` > `Builder` >
    // `Container` na każdy slot, bo `SlotBackgroundBuilder._build` zamieniał
    // `null` na `Container()`.
    expect(widgetsWithNullBuilder, widgetsWithoutBuilder + 1,
        reason: 'zmierzono: bez buildera $widgetsWithoutBuilder, '
            'z `null` $widgetsWithNullBuilder');
    expect(widgetsWithBackground, greaterThan(widgetsWithNullBuilder + slots),
        reason: 'a slot, który rysuje, kosztuje co najmniej widget na slot');
  });

  testWidgets('T-PV2-06 · montaż buduje każdy element RAZ',
      (WidgetTester tester) async {
    await pumpGrid(tester);

    final mounted = inTree(tester).length;
    expect(mounted, greaterThan(0));
    expect(tileMounts, mounted,
        reason: 'każdy element w drzewie zamontował się raz');
    // Przed zmianą `didUpdateWidget` czyścił `_widgetsMap` przy KAŻDEJ
    // przebudowie siatki, także tej, w której nic się nie zmieniło — więc
    // `Dashboard` rebudowany z własnego `setState` (`_listenOffset`) kazał
    // zbudować wszystko po raz drugi.
    expect(itemBuilderCalls, mounted,
        reason: 'i został zbudowany raz (zmierzono: $itemBuilderCalls wywołań '
            'na $mounted elementów)');
    expect(tileBuilds, mounted, reason: 'i narysowany raz');
  });

  testWidgets(
      'T-PV2-07 · tryb EDYCJI: przeciąganie elementu nie przebudowuje '
      'pozostałych', (WidgetTester tester) async {
    final controller = await pumpGrid(tester);

    controller.isEditing = true;
    await tester.pumpAndSettle();

    // Przeciąganie ZACZYNA się przed pomiarem, bo jego start zmienia
    // `_lastEditingId` i słusznie unieważnia cache (element w edycji wychodzi
    // z warstwy statycznej do własnej). Mierzymy KLATKĘ TRWAJĄCEGO ruchu.
    final target = tester.getRect(find.byKey(const ValueKey('tile_i02')));
    final gesture = await tester.startGesture(target.center);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    final ids = inTree(tester);
    final before = _framesById(tester, ids);

    // Ruch, który NAPRAWDĘ zmienia slot: wtedy `_onMoveUpdate` wyjmuje
    // przeciągany element z mapy, a `build` wkłada go z powrotem. To jest
    // zmiana zbioru kluczy, której cache statyczny NIE MA prawa zobaczyć —
    // element w edycji rysuje osobna warstwa (`_buildEditingOverlay`), a bump
    // rewizji na nim przebudowywałby całą siatkę pod palcem. To regresja, przed
    // którą cache powstał (`c3c4038`).
    //
    // PUŁAPKA zmierzona przy pisaniu: `_onMoveUpdate` jest DUSZONE zegarem
    // ŚCIENNYM (16 ms, `dashboard_stack.dart`), a test biegnie szybciej niż
    // klatka — bez realnego odczekania druga i każda następna aktualizacja
    // przeciągania jest po prostu wyrzucana i gest nic nie robi.
    final slotBefore = sceneItems[2].layoutData.startX;
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();

    // Kontrola, że pomiar nie jest próżny — bez zmiany slotu ta klatka nie
    // dotyka mapy i test nie mierzy wyjątku dla elementu w edycji.
    expect(sceneItems[2].layoutData.startX, isNot(slotBefore),
        reason: 'mierzona klatka musi PRZESTAWIĆ przeciągany element '
            '(slot $slotBefore → ${sceneItems[2].layoutData.startX})');

    expect(inTree(tester), ids, reason: 'przeciąganie nie rusza zbioru');
    final after = _framesById(tester, ids);
    final rebuilt =
        ids.where((id) => !identical(before[id], after[id])).toList();

    expect(rebuilt, contains('i02'),
        reason: 'przeciągany element jest budowany od nowa w każdej klatce '
            'ruchu — rysuje go warstwa nakładki');
    expect(
      rebuilt.where((id) => id != 'i02'),
      isEmpty,
      reason: 'ramki elementów INNYCH niż przeciągany zostają tymi SAMYMI '
          'obiektami (przebudowane: $rebuilt z $ids)',
    );

    await gesture.up();
    await tester.pumpAndSettle();

    // Druga połowa reguły: wyjście z edycji unieważnia cache, bo zmienia się
    // `_lastEditingId` — przeciągany element wraca do warstwy statycznej.
    controller.isEditing = false;
    await tester.pumpAndSettle();
    expect(inTree(tester), contains('i02'));
  });

  // =========================================================================
  // Luki pokrycia zgłoszone przez fazę C (A3) — cztery tezy, których nie
  // pinował ŻADEN test w obu repozytoriach, każda zweryfikowana mutacją.
  // =========================================================================

  testWidgets(
      'T-PV2-08 · warstwa tła jedzie DOKŁADNIE za offsetem i nie powstaje '
      'ani razu', (WidgetTester tester) async {
    await pumpGrid(tester);
    final position = axis(tester);

    double topOf(String key) => tester.getRect(find.byKey(ValueKey(key))).top;

    // Trzy offsety w obrębie JEDNEGO pasma (±500 px). Kontrakt (ii) §2.1(b)
    // planu brzmi „piksel w piksel ta sama pozycja każdego slotu", a jedynym
    // dowodem na dziś był diff wizualny z telefonu (kryterium 2 fazy B): mutacja
    // F3 fazy C — `AnimatedBuilder` zdjęty, `top` znowu z `− pixels` — ZAMRAŻA
    // całą kratkę slotów (zmierzone: `bg_0_3.top` 310,0 przy `pixels` 0, 40
    // i 120 zamiast 310/270/190) i przechodzi całą suitę forka oraz benchmark
    // aplikacji.
    final tops = <double, double>{};
    final gaps = <double, double>{};
    backgroundCalls = 0;
    for (final pixels in <double>[0, 40, 120]) {
      position.jumpTo(pixels);
      await tester.pump();
      tops[pixels] = topOf('bg_0_3');
      // Odstęp między slotem tła i KAFELKIEM w tym samym wierszu: obie warstwy
      // mają jechać jak jedna, więc różnica jest stała przy każdym offsecie.
      gaps[pixels] = topOf('bg_0_2') -
          tester.getRect(find.byKey(const ValueKey('tile_i01'))).top;
    }

    expect(backgroundCalls, 0,
        reason:
            'w obrębie pasma warstwa nie powstaje ani razu — gdyby powstała, '
            'poniższe pozycje byłyby zgodne „przez przypadek"');
    expect(tops[0]! - tops[40]!, closeTo(40, 0.01),
        reason: 'przewinięcie o 40 px przesuwa slot o 40 px '
            '(zmierzono: ${tops[0]} → ${tops[40]})');
    expect(tops[40]! - tops[120]!, closeTo(80, 0.01),
        reason: 'i o 80 px przy przewinięciu o 80 px '
            '(zmierzono: ${tops[40]} → ${tops[120]})');
    expect(gaps[40], closeTo(gaps[0]!, 0.01),
        reason: 'kratka slotów i kafelki jadą jak JEDNA warstwa '
            '(zmierzono odstępy: $gaps)');
    expect(gaps[120], closeTo(gaps[0]!, 0.01),
        reason: 'także po 120 px: $gaps');
    expect(topOf('bg_0_4') - topOf('bg_0_3'), closeTo(slotHeight, 0.01),
        reason: 'a wiersz slotów ma dokładnie wysokość slotu');
  });

  testWidgets(
      'T-PV2-09 · nowy `itemBuilder` unieważnia cache zamontowanych elementów',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = DashboardItemController<DashboardItem>(items: items());
    var built = 0;

    // Ten sam kontroler i ten sam układ; zmienia się TYLKO domknięcie
    // `itemBuilder`. Tak wygląda zmiana motywu u konsumenta: `CockpitGrid`
    // tworzy builder na nowo w swoim `dashboardBuilder`, i to jest jedyna droga,
    // którą zamontowany kafelek dowiaduje się o nowej treści. Mutacja M-b1b fazy
    // C (zdjęcie `itemBuilder` z `_parametersChangedFrom`) przechodziła suitę
    // forka ORAZ całą suitę aplikacji — kafelki zamarzłyby z treścią z chwili
    // budowy i nikt by tego nie zauważył.
    Widget tree(String marker) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: surface.width,
              height: surface.height,
              child: Dashboard<DashboardItem>(
                dashboardItemController: controller,
                slotCount: slotCount,
                slotHeight: slotHeight,
                itemStyle: const ItemStyle(
                  color: Colors.transparent,
                  type: MaterialType.transparency,
                ),
                editModeSettings: _editModeSettings,
                itemBuilder: (item) {
                  built++;
                  return Text('$marker:${item.identifier}');
                },
              ),
            ),
          ),
        );

    await tester.pumpWidget(tree('A'));
    await tester.pumpAndSettle();
    expect(find.text('A:i00'), findsOneWidget);

    built = 0;
    await tester.pumpWidget(tree('B'));
    await tester.pumpAndSettle();

    expect(find.text('B:i00'), findsOneWidget,
        reason: 'zamontowany element pokazuje treść z NOWEGO buildera');
    expect(find.text('A:i00'), findsNothing,
        reason: 'i nie zostaje przy starej');
    expect(built, greaterThan(0),
        reason: 'nowy builder został naprawdę zawołany (zmierzono: $built)');
  });

  testWidgets(
      'T-PV2-10 · `delete()` po przewinięciu: element znika, a start edycji '
      'nie rzuca', (WidgetTester tester) async {
    final controller = await pumpGrid(tester);

    axis(tester).jumpTo(1500);
    await tester.pump();

    final band = inTree(tester);
    expect(band, isNot(contains('i00')), reason: 'i00 jest już poza pasmem');
    final inBand = band.first;

    // `delete()` jest JEDYNĄ ścieżką, w której element wychodzi z mapy BEZ
    // jednoczesnego dodania innego: przewinięcie robi oba naraz, a dodanie
    // bumpuje rewizję, więc warstwa statyczna i tak powstaje z aktualnej mapy.
    // Dlatego ani F2 (rewizja tylko w `addWidget`), ani M-b3 (zamiatanie
    // martwych kluczy wyłączone) nie czerwieniły niczego w obu repozytoriach.
    // Zmierzone konsekwencje: usunięty element ZOSTAJE na ekranie, a przy
    // wyłączonym zamiataniu `delete()` + start sesji edycji rzuca „Null check
    // operator used on a null value".
    controller.delete('i00');
    await tester.pump();
    controller.delete(inBand);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(inTree(tester), isNot(contains(inBand)),
        reason: 'usunięty element wychodzi z drzewa '
            '(w drzewie: ${inTree(tester)})');
    expect(inTree(tester), isNotEmpty, reason: 'i nie zabiera reszty');

    // Pełny dowód: start sesji edycji przebudowuje warstwę statyczną z MAPY,
    // więc martwy klucz rzuciłby dopiero tutaj.
    controller.isEditing = true;
    await tester.pumpAndSettle();

    final alive = inTree(tester).first;
    final rect = tester.getRect(find.byKey(ValueKey('tile_$alive')));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'start sesji edycji po `delete()` nie ma prawa rzucić');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'T-PV2-11 · wiersz-widmo nad viewportem wchodzi w ekran i NIE jest '
      'obcinany', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Geometria z sondy fazy C: padding 8 i odstęp 4 dają wierszowi `y = −1`
    // `top = −90` przy wysokości 96, czyli **6 px W EKRANIE** — pasmo zaczyna
    // się nad viewportem (`floor(−500/100) = −5`), a `v0.0.7` te 6 px malował,
    // bo tnie wyłącznie ZEWNĘTRZNY `Stack`. Mutacja F8 (domyślny
    // `Clip.hardEdge` na wewnętrznym `Stack`u warstwy) uciełaby je i ZMIENIŁA
    // wygląd — dlatego dartdoc nazywa `Clip.none` obowiązkowym, a żaden test
    // tego nie widział.
    final controller = DashboardItemController<DashboardItem>(items: items());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: surface.width,
          height: surface.height,
          child: Dashboard<DashboardItem>(
            dashboardItemController: controller,
            slotCount: slotCount,
            slotHeight: slotHeight,
            padding: const EdgeInsets.all(8),
            horizontalSpace: 4,
            verticalSpace: 4,
            itemStyle: const ItemStyle(
              color: Colors.transparent,
              type: MaterialType.transparency,
            ),
            editModeSettings: _editModeSettings,
            slotBackgroundBuilder:
                SlotBackgroundBuilder.withFunction<DashboardItem>(
                    (context, item, x, y, editing) {
              return Container(key: ValueKey('bg_${x}_$y'));
            }),
            itemBuilder: (item) => Text(item.identifier),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final ghost = find.byKey(const ValueKey('bg_0_-1'));
    expect(ghost, findsOneWidget,
        reason:
            'pasmo zaczyna się nad viewportem, więc wiersz −1 JEST zbudowany');

    final rect = tester.getRect(ghost);
    final screen = Rect.fromLTWH(0, 0, surface.width, surface.height);
    expect(rect.top, lessThan(0), reason: 'wiersz −1 startuje nad ekranem');
    expect(rect.bottom, greaterThan(0),
        reason: 'ale wchodzi w ekran (zmierzono ${rect.bottom} px)');
    expect(rect.overlaps(screen), isTrue);

    // Druga połowa tezy — ta, którą czerwieni F8: pudełko wewnętrznego `Stack`a
    // warstwy jest UKŁADEM WSPÓŁRZĘDNYCH, nie viewportem. Sprawdzamy to na
    // najbliższym `Stack`u nad slotem, bo obcięcia nie widać w prostokątach:
    // `Clip.hardEdge` zabiera piksele przy MALOWANIU, a render boks zostaje.
    final layer = tester.widget<Stack>(
      find.ancestor(of: ghost, matching: find.byType(Stack)).first,
    );
    expect(layer.clipBehavior, Clip.none,
        reason:
            'warstwa tła nie obcina slotów pasma — granicą widoczności jest '
            'zewnętrzny `Stack` siatki');
  });
}

/// Ustawienia trybu edycji tworzone RAZ — patrz komentarz przy `grid`.
final EditModeSettings _editModeSettings = EditModeSettings(
  panEnabled: true,
  longPressEnabled: false,
  paintBackgroundLines: false,
);

/// Ramka elementu: NAJBLIŻSZY `AnimatedBuilder` nad jego treścią — ten, którym
/// siatka przesuwa element nad offsetem (`dashboard_item_widget.dart`).
///
/// Jego TOŻSAMOŚĆ jest jedynym publicznie widocznym śladem tego, czy warstwa
/// statyczna została przebudowana: `buildPositioned` tworzy wtedy nowy widget
/// elementu, a jego `State` buduje nowy `AnimatedBuilder`. Samo poddrzewo
/// elementu zostaje tym samym obiektem w obu przypadkach (siedzi w `child:`),
/// więc licznik przebudów kafelka tej różnicy nie widzi. Ramki szukamy PER
/// ELEMENT, bo w trybie edycji w drzewie stoją też `AnimatedBuilder`y, które do
/// żadnego elementu nie należą (malarz tła edycji) — zmierzone 9 na 6 elementów.
Map<String, AnimatedBuilder> _framesById(
  WidgetTester tester,
  List<String> ids,
) =>
    <String, AnimatedBuilder>{
      for (final id in ids)
        id: tester.widget<AnimatedBuilder>(find
            .ancestor(
              of: find.byKey(ValueKey('tile_$id')),
              matching: find.byType(AnimatedBuilder),
            )
            .first),
    };

class _CountingTile extends StatefulWidget {
  const _CountingTile({
    required this.id,
    required this.onMount,
    required this.onBuild,
  });

  final String id;
  final VoidCallback onMount;
  final VoidCallback onBuild;

  @override
  State<_CountingTile> createState() => _CountingTileState();
}

class _CountingTileState extends State<_CountingTile> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return Container(
      key: ValueKey('tile_${widget.id}'),
      color: Colors.blueGrey,
      alignment: Alignment.center,
      child: Text(widget.id),
    );
  }
}
