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
