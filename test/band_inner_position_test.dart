import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wave KB (consumer `sinum_dashboard`): the grid as the INNER position of a
/// One UI band, and the layout-time correction without `jumpTo`.
///
/// Dwie zmiany 0.0.11 i ich granice:
/// - `Dashboard.primary` (opt-in) — siatka przewija się na
///   `PrimaryScrollController` ciała `NestedScrollView`, więc gest na siatce
///   zwija i rozwija pasmo nad nią; domyślne `false` zostawia gołe `Scrollable`,
///   które kontrolera nie adoptuje (`scrollable.dart:590-591`, Flutter 3.47);
/// - korekta pozycji w `_setNewOffset` przez `correctBy` zamiast `jumpTo` —
///   `jumpTo` w fazie układu powiadamiał słuchaczy W ŚRODKU layoutu, a na pozycji
///   zagnieżdżonej był `coordinator.jumpTo` = `goIdle` + ruch pasma +
///   `goBallistic(0)` (`nested_scroll_view.dart:935-942`, `:1438-1439`).
///
/// Scena: elementy na całą szerokość (4×2) jeden pod drugim (`slotCount` 4,
/// `slotHeight` 100, więc element to 200 px treści i JEDEN pełny rząd —
/// elementy 2×2 siatka układa po dwa w rzędzie, a wtedy usunięcie ostatniego
/// nie skraca treści: zmierzone, maxExtent 500 przed i po), kadr 400×500 albo
/// 400×700 pod pasmem 300 px.
/// Wszystkie asercje są liczbami (offsety, bboxy, liczniki), bez progów czasowych.
void main() {
  const slotCount = 4;
  const slotHeight = 100.0;
  const itemExtent = 2 * slotHeight;
  const bandExtent = 300.0;

  late int itemBuilderCalls;
  late int backgroundCalls;

  setUp(() {
    itemBuilderCalls = 0;
    backgroundCalls = 0;
  });

  List<DashboardItem> items(int count) => <DashboardItem>[
        for (var i = 0; i < count; i++)
          DashboardItem(
            identifier: 'i${i.toString().padLeft(2, '0')}',
            width: slotCount,
            height: 2,
            startX: 0,
            startY: i * 2,
          ),
      ];

  /// `itemBuilder` i budowniczy tła tworzone RAZ na test — ta sama tożsamość
  /// przy każdej budowie, tak jak u konsumenta (PV-g). Świeże domknięcie na
  /// każdą budowę samo w sobie czyściłoby cache kafelków i fałszowało liczniki.
  late DashboardItemBuilder<DashboardItem> itemBuilder;
  late SlotBackgroundBuilder<DashboardItem> background;

  setUp(() {
    itemBuilder = (item) {
      itemBuilderCalls++;
      return Container(
        key: ValueKey('tile_${item.identifier}'),
        color: Colors.blueGrey,
      );
    };
    background = SlotBackgroundBuilder.withFunction<DashboardItem>(
        (context, item, x, y, editing) {
      backgroundCalls++;
      return Container(key: ValueKey('bg_${x}_$y'));
    });
  });

  Dashboard<DashboardItem> dashboard(
    DashboardItemController<DashboardItem> controller, {
    bool primary = false,
    ScrollController? scrollController,
  }) =>
      Dashboard<DashboardItem>(
        dashboardItemController: controller,
        slotCount: slotCount,
        slotHeight: slotHeight,
        scrollController: scrollController,
        primary: primary,
        itemStyle: _itemStyle,
        editModeSettings: _editModeSettings,
        slotBackgroundBuilder: background,
        itemBuilder: itemBuilder,
      );

  /// Siatka BEZ argumentu `primary:` — `T-KB2-05` mierzy wartość DOMYŚLNĄ
  /// konstruktora, nie jawne `false`.
  Dashboard<DashboardItem> defaultDashboard(
    DashboardItemController<DashboardItem> controller,
  ) =>
      Dashboard<DashboardItem>(
        dashboardItemController: controller,
        slotCount: slotCount,
        slotHeight: slotHeight,
        itemStyle: _itemStyle,
        editModeSettings: _editModeSettings,
        slotBackgroundBuilder: background,
        itemBuilder: itemBuilder,
      );

  /// Pasmo One UI w miniaturze: nagłówek 300 px, który przewija się poza ekran
  /// (outer), i siatka jako ciało (inner).
  Widget nested(Widget grid, ScrollController outer) => MaterialApp(
        home: Scaffold(
          body: NestedScrollView(
            controller: outer,
            headerSliverBuilder: (context, inner) => const <Widget>[
              SliverToBoxAdapter(
                child: SizedBox(key: Key('band'), height: bandExtent),
              ),
            ],
            body: grid,
          ),
        ),
      );

  Finder gridScrollable() => find.descendant(
        of: find.byWidgetPredicate((w) => w is Dashboard),
        matching: find.byType(Scrollable),
      );

  ScrollPosition gridPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(gridScrollable()).position;

  /// Gest krokowy: palec w środku siatki, [dy] w [steps] krokach z klatką po
  /// każdym, potem puszczenie i dokończenie animacji.
  Future<void> dragGrid(WidgetTester tester, double dy,
      {int steps = 10}) async {
    final center = tester.getCenter(gridScrollable());
    final gesture = await tester.startGesture(center);
    for (var s = 0; s < steps; s++) {
      await gesture.moveBy(Offset(0, dy / steps));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Górna krawędź kafelka [id] w układzie TREŚCI siatki: pozycja na ekranie
  /// względem kadru siatki plus `pixels`. Dla spójnej klatki ta liczba nie
  /// zależy od przewinięcia.
  double contentTop(WidgetTester tester, String id) {
    final frameTop = tester.getRect(gridScrollable()).top;
    final tileTop = tester.getRect(find.byKey(ValueKey('tile_$id'))).top;
    return tileTop - frameTop + gridPosition(tester).pixels;
  }

  /// Słuchacz, który liczy notyfikacje kontrolera W FAZIE UKŁADU (build/layout
  /// to `SchedulerPhase.persistentCallbacks`). `correctBy` nie powiadamia nikogo;
  /// `jumpTo` w `_setNewOffset` powiadamiał właśnie tu.
  int Function() countLayoutNotifications(ScrollController controller) {
    var count = 0;
    void listener() {
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        count++;
      }
    }

    controller.addListener(listener);
    addTearDown(() => controller.removeListener(listener));
    return () => count;
  }

  testWidgets(
      'T-KB2-01 · Dashboard(primary: true) jako ciało NestedScrollView: drag w '
      'dół przy pixels 0 rozwija outer, drag w górę zwija outer, potem '
      'przewija siatkę; zero wyjątków', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final outer = ScrollController();
    addTearDown(outer.dispose);
    final controller = DashboardItemController<DashboardItem>(items: items(10));
    await tester
        .pumpWidget(nested(dashboard(controller, primary: true), outer));
    await tester.pumpAndSettle();

    // Adopcja zmierzona wprost: kontroler `Scrollable` siatki to TEN SAM obiekt,
    // który `NestedScrollView` wystawia ciału jako `PrimaryScrollController`.
    final nestedState =
        tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
    expect(
      tester.widget<Scrollable>(gridScrollable()).controller,
      same(nestedState.innerController),
      reason: 'primary: true = siatka na kontrolerze wewnętrznym pasma',
    );

    // Start jak w aplikacji: pasmo zwinięte, siatka u góry.
    outer.jumpTo(outer.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(outer.offset, bandExtent);
    expect(gridPosition(tester).pixels, 0);

    // Palec w DÓŁ przy pixels 0: siatka nie ma dokąd jechać, ruch bierze pasmo.
    await dragGrid(tester, 200);
    final afterDown = outer.offset;
    expect(afterDown, lessThan(bandExtent),
        reason: 'drag w dół na siatce rozwija pasmo (outer: $afterDown)');
    expect(gridPosition(tester).pixels, 0,
        reason: 'siatka stoi przy 0, kiedy rozwija się pasmo');

    // Palec w GÓRĘ: najpierw zwija się pasmo, potem jedzie siatka.
    await dragGrid(tester, -600, steps: 20);
    expect(outer.offset, bandExtent,
        reason: 'drag w górę zwija pasmo do końca');
    expect(gridPosition(tester).pixels, greaterThan(0),
        reason: 'a nadmiar gestu przewija siatkę '
            '(pixels: ${gridPosition(tester).pixels})');

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'T-KB2-02 · siatka przewinięta do dołu, usunięcie ostatniego rzędu: '
      'pixels == nowy maxExtent po jednej klatce, bbox dolnego kafelka spójny '
      'z pixels, zero wyjątków, bez jumpTo (zero notyfikacji kontrolera w '
      'fazie układu)', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final controller = DashboardItemController<DashboardItem>(items: items(10));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: dashboard(controller, scrollController: scroll),
      ),
    ));
    await tester.pumpAndSettle();

    final position = gridPosition(tester);
    final maxBefore = position.maxScrollExtent;
    expect(maxBefore, greaterThan(itemExtent),
        reason: 'scena musi mieć co najmniej rząd do usunięcia ponad kadrem');
    position.jumpTo(maxBefore);
    await tester.pumpAndSettle();
    expect(position.pixels, maxBefore);

    // Punkt odniesienia: gdzie w TREŚCI stoi przedostatni kafelek. Ta liczba nie
    // zależy od przewinięcia, więc po usunięciu ostatniego ma zostać ta sama.
    final topBefore = contentTop(tester, 'i08');
    final layoutNotifications = countLayoutNotifications(scroll);

    controller.delete('i09');
    await tester.pump();

    // Kontrakt korekty: JEDNA klatka i pozycja stoi na nowym końcu zakresu.
    final expectedMax = maxBefore - itemExtent;
    expect(position.maxScrollExtent, moreOrLessEquals(expectedMax),
        reason: 'zakres krótszy dokładnie o usunięty rząd');
    expect(position.pixels, moreOrLessEquals(expectedMax),
        reason: 'pixels skorygowane do nowego maxExtent w tej samej klatce');

    // Bbox kafelka spójny z pixels: kafelki przesuwają się WŁASNYM
    // `AnimatedBuilder`em nad offsetem (`dashboard_item_widget.dart:299-313`),
    // a `correctBy` słuchaczy nie powiadamia — gdyby nikt ich nie przebudował,
    // kafelek stałby na ekranie tam, gdzie przy STARYM pixels, czyli 200 px
    // wyżej, a jego „pozycja w treści" policzona z nowym pixels rozjechałaby się
    // dokładnie o tę korektę.
    expect(contentTop(tester, 'i08'), moreOrLessEquals(topBefore),
        reason: 'kafelek i08 narysowany przy bieżącym pixels');
    final frame = tester.getRect(gridScrollable());
    final tile = tester.getRect(find.byKey(const ValueKey('tile_i08')));
    expect(tile.bottom, lessThanOrEqualTo(frame.bottom + 0.001),
        reason: 'dolny kafelek mieści się w kadrze ($tile w $frame)');
    expect(tile.top, greaterThanOrEqualTo(frame.top),
        reason: 'i jest w kadrze, a nie nad nim ($tile w $frame)');
    expect(find.byKey(const ValueKey('tile_i09')), findsNothing);

    expect(layoutNotifications(), 0,
        reason: 'korekta w układzie nie powiadamia słuchaczy — `jumpTo` '
            'robił to w środku layoutu');
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(position.pixels, moreOrLessEquals(expectedMax),
        reason: 'i nic jej potem nie przesuwa');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'T-KB2-03 · to samo pod NestedScrollView: outer offset niezmieniony, '
      'zero wyjątków', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final outer = ScrollController();
    addTearDown(outer.dispose);
    final controller = DashboardItemController<DashboardItem>(items: items(10));
    await tester
        .pumpWidget(nested(dashboard(controller, primary: true), outer));
    await tester.pumpAndSettle();

    final inner = tester
        .state<NestedScrollViewState>(find.byType(NestedScrollView))
        .innerController;

    // Pasmo zwinięte, siatka do samego dołu — gestem, jak użytkownik.
    outer.jumpTo(outer.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await dragGrid(tester, -3000, steps: 30);
    final position = gridPosition(tester);
    final maxBefore = position.maxScrollExtent;
    expect(position.pixels, moreOrLessEquals(maxBefore),
        reason: 'siatka przewinięta do końca');
    final outerBefore = outer.offset;
    expect(outerBefore, bandExtent, reason: 'pasmo zwinięte');

    final topBefore = contentTop(tester, 'i08');
    final innerNotifications = countLayoutNotifications(inner);
    final outerNotifications = countLayoutNotifications(outer);

    controller.delete('i09');
    await tester.pump();

    final expectedMax = maxBefore - itemExtent;
    expect(position.pixels, moreOrLessEquals(expectedMax),
        reason: 'pozycja wewnętrzna na nowym końcu po jednej klatce');
    expect(outer.offset, outerBefore, reason: 'korekta siatki nie rusza pasma');
    expect(contentTop(tester, 'i08'), moreOrLessEquals(topBefore),
        reason: 'kafelek narysowany przy bieżącym pixels');
    expect(innerNotifications(), 0,
        reason: 'kontroler wewnętrzny bez notyfikacji w fazie układu');
    expect(outerNotifications(), 0,
        reason: 'kontroler pasma bez notyfikacji w fazie układu');
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(outer.offset, outerBefore,
        reason: 'także po wygaszeniu animacji — żadnej balistyki z układu');
    expect(position.pixels, moreOrLessEquals(expectedMax));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'T-KB2-04 · wysokość viewportu oscyluje 440↔720 przy pixels 0 '
      '(symulacja ruchu pasma): warstwa tła slotów zbudowana RAZ, itemBuilder '
      '0 wywołań', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Pięć elementów = 1000 px treści: przy kadrze 440 pasmo (`cacheExtend` 500)
    // sięga 940 px, więc trzyma wszystkie; siatka przewijalna przy obu
    // wysokościach (maxExtent 560 i 280).
    final controller = DashboardItemController<DashboardItem>(items: items(5));
    final height = ValueNotifier<double>(440);
    addTearDown(height.dispose);

    // Siatka zbudowana RAZ i podana jako `child` — rodzic zmienia tylko więzy,
    // dokładnie tak jak pasmo, które przesuwa ciało, nie przebudowując go.
    final grid = dashboard(controller);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: height,
            child: grid,
            builder: (context, h, child) =>
                SizedBox(width: 400, height: h, child: child),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(backgroundCalls, greaterThan(0),
        reason: 'montaż buduje warstwę tła raz — inaczej nie ma czego mierzyć');
    expect(itemBuilderCalls, 5, reason: 'montaż buduje każdy element raz');
    expect(gridPosition(tester).pixels, 0);

    final itemsAtMount = itemBuilderCalls;
    var layerBuilds = 0;
    final heights = <double>[];
    for (var cycle = 0; cycle < 6; cycle++) {
      for (final h in const <double>[720, 440]) {
        final before = backgroundCalls;
        height.value = h;
        await tester.pump();
        heights.add(tester.getSize(gridScrollable()).height);
        if (backgroundCalls > before) layerBuilds++;
      }
    }

    expect(heights.toSet(), <double>{720, 440},
        reason: 'kadr siatki naprawdę oscylował (zmierzono: $heights)');
    expect(layerBuilds, 0,
        reason: 'ruch pasma ≤ cacheExtend nie wyprowadza kadru z pasa tła — '
            'warstwa tła zostaje ta z montażu');
    expect(itemBuilderCalls - itemsAtMount, 0,
        reason: 'i żaden kafelek nie jest budowany od nowa');
    expect(gridPosition(tester).pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'T-KB2-05 · primary: false (domyślne) pod NestedScrollView: siatka NIE '
      'adoptuje kontrolera (outer stoi przy dragu siatki) — zachowanie v0.0.10',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final outer = ScrollController();
    addTearDown(outer.dispose);
    final controller = DashboardItemController<DashboardItem>(items: items(10));
    // Konstruktor BEZ `primary:` — mierzymy wartość domyślną.
    await tester.pumpWidget(nested(defaultDashboard(controller), outer));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<Dashboard>(find.byWidgetPredicate((w) => w is Dashboard))
            .primary,
        isFalse,
        reason: 'domyślne primary to false');
    expect(tester.widget<Scrollable>(gridScrollable()).controller, isNull,
        reason: 'gołe Scrollable nie dostaje kontrolera pasma');

    // Pasmo ROZWINIĘTE: przy adopcji drag w górę na siatce zwinąłby je pierwszy.
    expect(outer.offset, 0);
    await dragGrid(tester, -300);

    expect(outer.offset, 0,
        reason: 'pasmo stoi — siatka przewija WŁASNĄ pozycję');
    expect(gridPosition(tester).pixels, greaterThan(0),
        reason: 'a siatka jedzie (pixels: ${gridPosition(tester).pixels})');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'T-KB2-06 · primary: true bez PrimaryScrollController w drzewie: siatka '
      'przewija się jak dziś', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Trasa `MaterialApp` sama wystawia `PrimaryScrollController`
    // (`_ModalScopeState`), więc „bez kontrolera w drzewie" trzeba zrobić
    // jawnie: `PrimaryScrollController.none`. Ten sam gest dla `false` i `true`
    // musi dać tę samą pozycję.
    final measured = <bool, double>{};
    for (final primary in const <bool>[false, true]) {
      final controller =
          DashboardItemController<DashboardItem>(items: items(10));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrimaryScrollController.none(
            child: KeyedSubtree(
              // Nowy klucz = nowa siatka, a nie aktualizacja poprzedniej.
              key: ValueKey('grid_$primary'),
              child: dashboard(controller, primary: primary),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.widget<Scrollable>(gridScrollable()).controller, isNull,
          reason:
              'primary: $primary bez przodka = własny kontroler Scrollable');
      expect(gridPosition(tester).pixels, 0);

      await dragGrid(tester, -300);
      measured[primary] = gridPosition(tester).pixels;
      expect(tester.takeException(), isNull);
    }

    expect(measured[false], greaterThan(0),
        reason: 'gest przewija siatkę (zmierzono: $measured)');
    expect(measured[true], measured[false],
        reason: 'primary: true bez kontrolera w drzewie = zachowanie v0.0.10 '
            '(zmierzono: $measured)');
  });

  /// Słuchacz, który liczy notyfikacje kontrolera POZA fazą układu (np.
  /// `SchedulerPhase.postFrameCallbacks`) — tam korekta oddaje słuchaczom
  /// wiadomość o nowym pixels, którą `jumpTo` z v0.0.10 dawał w środku layoutu.
  int Function() countNotificationsOutsideLayout(ScrollController controller) {
    var count = 0;
    void listener() {
      if (SchedulerBinding.instance.schedulerPhase !=
          SchedulerPhase.persistentCallbacks) {
        count++;
      }
    }

    controller.addListener(listener);
    addTearDown(() => controller.removeListener(listener));
    return () => count;
  }

  /// Odstęp dolnej krawędzi kafelka [id] od dolnej krawędzi kadru siatki.
  double bottomGap(WidgetTester tester, String id) =>
      tester.getRect(gridScrollable()).bottom -
      tester.getRect(find.byKey(ValueKey('tile_$id'))).bottom;

  testWidgets(
      'T-KB2-07 · siatka przewinięta do dołu, viewport ROŚNIE 600 → 900 px '
      '(maxExtent maleje): po jednej klatce pixels == maxScrollExtent ORAZ bbox '
      'dolnego kafelka przy dolnej krawędzi (bez pustego pasa), zero '
      'notyfikacji w fazie układu, zero wyjątków', (WidgetTester tester) async {
    // Anomalia A3 fazy B: przy ZMIANIE TREŚCI stos przebudowuje się sam, przy
    // zmianie WYMIARU kadru — nie; kafelki stały na starym pixels (pusty pas
    // 300 px na dole) do następnego zdarzenia przewijania.
    //
    // PIĘĆ elementów (1000 px treści), nie dziesięć: pas `cacheExtend` (500)
    // musi już trzymać WSZYSTKIE, żeby wzrost kadru nie dołożył klucza. Nowy
    // klucz w pasie przebudowuje listę kafelków stosu (rewizja `_widgetsMap`)
    // i przy okazji ustawia je na bieżącym pixels — z dziesięcioma elementami
    // ten test był ZIELONY na v0.0.11 (zmierzone), czyli maskował A3.
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final controller = DashboardItemController<DashboardItem>(items: items(5));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: dashboard(controller, scrollController: scroll),
      ),
    ));
    await tester.pumpAndSettle();

    final position = gridPosition(tester);
    final maxBefore = position.maxScrollExtent;
    position.jumpTo(maxBefore);
    await tester.pumpAndSettle();
    expect(position.pixels, maxBefore);
    final gapBefore = bottomGap(tester, 'i04');
    final topBefore = contentTop(tester, 'i04');
    // Odstęp to tylko margines kafelka (zmierzone: 4 px), nie rząd.
    expect(gapBefore, inInclusiveRange(0, 10),
        reason: 'na końcu zakresu dolny kafelek przy dolnej krawędzi');
    final layoutNotifications = countLayoutNotifications(scroll);
    final laterNotifications = countNotificationsOutsideLayout(scroll);
    final itemsBefore = itemBuilderCalls;

    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pump();

    final expectedMax = maxBefore - 300;
    expect(tester.getSize(gridScrollable()).height, 900,
        reason: 'kadr naprawdę urósł');
    expect(position.maxScrollExtent, moreOrLessEquals(expectedMax),
        reason: 'zakres krótszy dokładnie o przyrost kadru');
    expect(position.pixels, moreOrLessEquals(position.maxScrollExtent),
        reason: 'pixels skorygowane do nowego maxExtent w tej samej klatce');

    // Bbox: kafelek narysowany przy SKORYGOWANYM pixels. Bez notyfikacji
    // `AnimatedBuilder` kafelka (`dashboard_item_widget.dart:299-313`) trzyma
    // `top` policzony ze starego pixels: dolny kafelek kończy się 300 px nad
    // dolną krawędzią, a pod nim jest pusty pas.
    expect(bottomGap(tester, 'i04'), moreOrLessEquals(gapBefore),
        reason: 'dolny kafelek przy dolnej krawędzi kadru, bez pustego pasa '
            '(odstęp ${bottomGap(tester, 'i04')} px)');
    expect(contentTop(tester, 'i04'), moreOrLessEquals(topBefore),
        reason: 'kafelek i04 narysowany przy bieżącym pixels');

    expect(layoutNotifications(), 0,
        reason: 'korekta nadal bez notyfikacji w fazie układu');
    expect(laterNotifications(), 1,
        reason: 'słuchacze kontrolera dowiadują się o korekcie RAZ, po klatce');
    expect(itemBuilderCalls - itemsBefore, 0,
        reason: 'przestawienie kafelków nie buduje ich treści od nowa');
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(position.pixels, moreOrLessEquals(expectedMax),
        reason: 'i nic jej potem nie przesuwa');
    expect(bottomGap(tester, 'i04'), moreOrLessEquals(gapBefore));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'T-KB2-08 · to samo pod NestedScrollView (kokpit pod pasmem 400×600 → '
      '400×900): outer offset bez zmian, dolny kafelek przy dolnej krawędzi, '
      'zero wyjątków', (WidgetTester tester) async {
    // Pięć elementów — powód jak w T-KB2-07 (pas cache trzyma wszystkie).
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final outer = ScrollController();
    addTearDown(outer.dispose);
    final controller = DashboardItemController<DashboardItem>(items: items(5));
    await tester
        .pumpWidget(nested(dashboard(controller, primary: true), outer));
    await tester.pumpAndSettle();

    final inner = tester
        .state<NestedScrollViewState>(find.byType(NestedScrollView))
        .innerController;

    // Pasmo zwinięte, siatka do samego dołu — gestem, jak użytkownik.
    outer.jumpTo(outer.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await dragGrid(tester, -3000, steps: 30);
    final position = gridPosition(tester);
    final maxBefore = position.maxScrollExtent;
    expect(position.pixels, moreOrLessEquals(maxBefore),
        reason: 'siatka przewinięta do końca');
    final outerBefore = outer.offset;
    expect(outerBefore, bandExtent, reason: 'pasmo zwinięte');
    final gapBefore = bottomGap(tester, 'i04');
    final topBefore = contentTop(tester, 'i04');
    final innerNotifications = countLayoutNotifications(inner);
    final outerNotifications = countLayoutNotifications(outer);
    final innerLater = countNotificationsOutsideLayout(inner);
    final outerLater = countNotificationsOutsideLayout(outer);

    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pump();

    final expectedMax = maxBefore - 300;
    expect(position.maxScrollExtent, moreOrLessEquals(expectedMax),
        reason: 'kadr wewnętrzny urósł o 300 px');
    expect(position.pixels, moreOrLessEquals(expectedMax),
        reason: 'pozycja wewnętrzna na nowym końcu po jednej klatce');
    expect(outer.offset, outerBefore, reason: 'korekta siatki nie rusza pasma');
    expect(bottomGap(tester, 'i04'), moreOrLessEquals(gapBefore),
        reason: 'dolny kafelek przy dolnej krawędzi, bez pustego pasa '
            '(odstęp ${bottomGap(tester, 'i04')} px)');
    expect(contentTop(tester, 'i04'), moreOrLessEquals(topBefore),
        reason: 'kafelek narysowany przy bieżącym pixels');
    expect(innerNotifications(), 0,
        reason: 'kontroler wewnętrzny bez notyfikacji w fazie układu');
    expect(outerNotifications(), 0,
        reason: 'kontroler pasma bez notyfikacji w fazie układu');
    expect(innerLater(), 1,
        reason: 'kontroler wewnętrzny dowiaduje się o korekcie RAZ, po klatce');
    expect(outerLater(), 0, reason: 'kontroler pasma nie dowiaduje się wcale');
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(outer.offset, outerBefore,
        reason: 'także po wygaszeniu animacji — żadnej balistyki z układu');
    expect(position.pixels, moreOrLessEquals(expectedMax));
    expect(bottomGap(tester, 'i04'), moreOrLessEquals(gapBefore));
    expect(tester.takeException(), isNull);
  });
}

/// Styl i ustawienia edycji tworzone RAZ — ta sama tożsamość przy każdej
/// budowie (`_parametersChangedFrom` w `dashboard_stack.dart`).
const ItemStyle _itemStyle = ItemStyle(
  color: Colors.transparent,
  type: MaterialType.transparency,
);

final EditModeSettings _editModeSettings = EditModeSettings(
  panEnabled: true,
  longPressEnabled: false,
  paintBackgroundLines: false,
);
