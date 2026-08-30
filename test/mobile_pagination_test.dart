import 'package:dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage F6: paging the tablet carousel by a whole block of sections.
///
/// The arithmetic is asked through the public [MobileCarouselConfig], the way
/// the wrapper itself asks it; the last test mounts the real wrapper, so the
/// wiring between page index and section index is covered end to end.
void main() {
  const defaultStep = MobileCarouselConfig(visibleSectionsOnTablet: 2);
  const step2 = MobileCarouselConfig(
    visibleSectionsOnTablet: 2,
    sectionStepOnTablet: 2,
  );

  test('T-F6f-01 · krok domyślny (null) zachowuje dotychczasową paginację', () {
    // Stara arytmetyka: pages = sections - (visible - 1), sekcja = numer strony.
    for (var sections = 1; sections <= 6; sections++) {
      final expectedPages = sections - 1 > 0 ? sections - 1 : 1;
      expect(defaultStep.totalPagesFor(DeviceType.tablet, sections),
          expectedPages,
          reason: 'sekcji: $sections');
      for (var page = 0; page < expectedPages; page++) {
        expect(defaultStep.sectionForPage(DeviceType.tablet, sections, page),
            page,
            reason: 'sekcji: $sections, strona: $page');
      }
    }

    // Konkret z diagnozy: 3 sekcje, 2 widoczne → 2 strony, sekcje 0 i 1.
    expect(defaultStep.totalPagesFor(DeviceType.tablet, 3), 2);
    expect(defaultStep.sectionForPage(DeviceType.tablet, 3, 0), 0);
    expect(defaultStep.sectionForPage(DeviceType.tablet, 3, 1), 1);
  });

  test('T-F6f-02 · krok 2 przy 3 sekcjach: 2 strony, ostatnia sklamrowana', () {
    expect(step2.totalPagesFor(DeviceType.tablet, 3), 2);
    expect(step2.sectionForPage(DeviceType.tablet, 3, 0), 0);
    // 1 · 2 = 2 byłoby stroną z jedną sekcją i pustką po prawej — klamra
    // cofa ją do ostatniego pełnego widoku.
    expect(step2.sectionForPage(DeviceType.tablet, 3, 1), 1);
  });

  test('T-F6f-03 · krok 2 przy 4 sekcjach: 2 strony bez wspólnej sekcji', () {
    expect(step2.totalPagesFor(DeviceType.tablet, 4), 2);
    expect(step2.sectionForPage(DeviceType.tablet, 4, 0), 0);
    expect(step2.sectionForPage(DeviceType.tablet, 4, 1), 2);

    // Zbiory sekcji obu stron są rozłączne.
    final first = {0, 1};
    final second = {2, 3};
    expect(first.intersection(second), isEmpty);
  });

  test('T-F6f-04 · krok 2 przy 5 sekcjach: 3 strony, sekcje 0, 2 i 3', () {
    expect(step2.totalPagesFor(DeviceType.tablet, 5), 3);
    expect(step2.sectionForPage(DeviceType.tablet, 5, 0), 0);
    expect(step2.sectionForPage(DeviceType.tablet, 5, 1), 2);
    // 2 · 2 = 4, ale ostatni pełny widok zaczyna się na sekcji 3.
    expect(step2.sectionForPage(DeviceType.tablet, 5, 2), 3);
  });

  test('T-F6f-05 · sekcji nie więcej niż widocznych → jedna strona', () {
    for (final config in [defaultStep, step2]) {
      for (final sections in [1, 2]) {
        expect(config.totalPagesFor(DeviceType.tablet, sections), 1,
            reason: 'sekcji: $sections');
        expect(config.sectionForPage(DeviceType.tablet, sections, 0), 0);
        // Numer strony spoza zakresu nie wyprowadza poza sekcję 0.
        expect(config.sectionForPage(DeviceType.tablet, sections, 5), 0);
      }
    }
  });

  test('T-F6f-06 · krok dotyczy tylko tabletu — telefon zostaje przy 1', () {
    const mobile = MobileCarouselConfig(
      visibleSectionsOnMobile: 1,
      sectionStepOnTablet: 2,
    );
    expect(mobile.totalPagesFor(DeviceType.mobile, 4), 4);
    for (var page = 0; page < 4; page++) {
      expect(mobile.sectionForPage(DeviceType.mobile, 4, page), page);
    }
  });

  test('T-F6f-07 · krok 0 zachowuje się jak 1, nie zeruje wszystkich stron',
      () {
    const zero = MobileCarouselConfig(
      visibleSectionsOnTablet: 2,
      sectionStepOnTablet: 0,
    );
    expect(zero.totalPagesFor(DeviceType.tablet, 4), 3);
    expect(zero.sectionForPage(DeviceType.tablet, 4, 1), 1);
  });

  testWidgets(
      'T-F6f-08 · 800×480: 4 sekcje z krokiem 2 dają 2 kropki i rozłączne strony',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Krok domyślny na tych samych danych: 3 strony, sekcje 0/1/2 (S2 i S3
    // pokazują się dwa razy) — punkt odniesienia dla asercji niżej.
    await tester.pumpWidget(_wrapper(defaultStep));
    await tester.pumpAndSettle();
    expect(_dotCount(tester), 3);
    expect(find.text('Sekcje 1-2 z 4'), findsOneWidget);

    await tester.pumpWidget(_wrapper(step2));
    await tester.pumpAndSettle();

    expect(_dotCount(tester), 2);
    expect(find.text('Sekcje 1-2 z 4'), findsOneWidget);

    // Druga kropka → druga strona: sekcje 3-4, żadnej wspólnej z pierwszą.
    await tester.tap(find.byType(AnimatedContainer).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Sekcje 3-4 z 4'), findsOneWidget);
  });
}

/// Number of carousel dots on screen. Only the dots use [AnimatedContainer]
/// in this package, and the grid below is built from plain containers.
int _dotCount(WidgetTester tester) => tester
    .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
    .where((c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle)
    .length;

/// 24 slots cut every 6 columns → 4 sections.
Widget _wrapper(MobileCarouselConfig config) {
  final controller = DashboardItemController<DashboardItem>(
    items: [DashboardItem(identifier: 'a', width: 1, height: 1)],
  );
  return MaterialApp(
    home: Scaffold(
      body: MobileDashboardWrapper<DashboardItem>(
        dashboardItemController: controller,
        slotCount: 24,
        columnsPerPage: 6,
        mobileConfig: config,
        dashboardBuilder: (ctrl, slotCount, startColumn, isMobile) =>
            Dashboard<DashboardItem>(
          dashboardItemController: ctrl,
          slotCount: slotCount,
          slotHeight: 40,
          itemBuilder: (item) => Container(key: Key('tile_${item.identifier}')),
        ),
      ),
    ),
  );
}
