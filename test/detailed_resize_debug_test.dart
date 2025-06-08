import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dashboard/dashboard.dart';

void main() {
  group('Detailed Resize Debug Tests', () {
    testWidgets(
        '🔍 DOKŁADNA analiza resize na lewej krawędzi z virtual columns',
        (WidgetTester tester) async {
      print('📋 Szczegółowy test diagnostyczny resize');

      // Konfiguracja identyczna z rzeczywistym problemem
      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(
          identifier: 'test_widget',
          width: 2,
          height: 1,
          startX: 3, // Widget w kolumnach 3-4
          startY: 0,
          minWidth: 1,
        ),
      ]);

      final virtualConfig = VirtualColumnsConfig.visible(
        disabledColumns: [1, 2], // Kolumny 1,2 są virtual (8% szerokości każda)
        disabledColumnWidth: 0.08,
      );

      print('🔧 Konfiguracja:');
      print('   - Widget: kolumny 3-4 (szerokość: 2)');
      print('   - Virtual columns: [1, 2] (8% każda)');
      print('   - Total slot count: 6');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600, // Stała szerokość dla przewidywalności
              height: 400,
              child: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    border: Border.all(color: Colors.red, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      'DEBUG WIDGET\n(${item.layoutData.startX}-${item.layoutData.startX + item.layoutData.width - 1})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                dashboardItemController: controller,
                slotCount: 6,
                slotHeight: 100,
                virtualColumnsConfig: virtualConfig,
                editModeSettings: EditModeSettings(
                  resizeCursorSide:
                      25, // Większy obszar dla łatwiejszego testowania
                  longPressEnabled: true,
                  panEnabled: true,
                  paintBackgroundLines: true,
                  fillEditingBackground: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      print('✅ Dashboard załadowany');

      // Znajdź widget
      final widgetFinder = find.text('DEBUG WIDGET\n(3-4)');
      expect(widgetFinder, findsOneWidget);
      print('🎯 Widget znaleziony');

      // Aktywuj edit mode
      await tester.longPress(widgetFinder);
      await tester.pumpAndSettle();
      print('👆 Edit mode aktywowany');

      // Sprawdź pozycję i rozmiar widgetu
      final widgetRect = tester.getRect(widgetFinder);
      print('📐 Widget rect: $widgetRect');
      print('   Left: ${widgetRect.left}');
      print('   Right: ${widgetRect.right}');
      print('   Width: ${widgetRect.width}');
      print('   Center: ${widgetRect.center}');

      // PIERWSZY TEST: Jak w working test - zaczynamy gesture na krawędzi z krótkim ruchem
      print('');
      print('🧪 TEST 1: Resize na lewej krawędzi (jak w working test)');
      final leftCenterPoint = Offset(widgetRect.left + 5, widgetRect.center.dy);
      print('🎯 Punkt testowy: $leftCenterPoint');

      print('🔍 Rozpoczynamy gesture na lewej krawędzi (jak working test)');

      final gesture1 = await tester.startGesture(leftCenterPoint);
      await tester.pump(const Duration(milliseconds: 100));
      print('📍 Gesture rozpoczęty na lewej krawędzi');

      // Pojedynczy ruch w lewo (jak w working test)
      await gesture1.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 100));
      print('⬅️ Resize w lewo o -40px (jak w working test)');

      await gesture1.up();
      await tester.pumpAndSettle();
      print('🔚 Gesture 1 zakończony');

      // DRUGI TEST: Kliknij górny róg lewej krawędzi
      print('');
      print('🧪 TEST 2: Resize na górnym rogu lewej krawędzi');
      final leftTopPoint = Offset(widgetRect.left + 3, widgetRect.top + 10);
      print('🎯 Punkt testowy: $leftTopPoint');

      final gesture2 = await tester.startGesture(leftTopPoint);
      await tester.pump(const Duration(milliseconds: 200));
      print('📍 Gesture rozpoczęty na górnym rogu');

      await gesture2.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 100));
      print('⬅️ Duże przesunięcie o -50px');

      await gesture2.up();
      await tester.pumpAndSettle();
      print('🔚 Gesture 2 zakończony');

      // TRZECI TEST: Kliknij dolny róg lewej krawędzi
      print('');
      print('🧪 TEST 3: Resize na dolnym rogu lewej krawędzi');
      final leftBottomPoint =
          Offset(widgetRect.left + 3, widgetRect.bottom - 10);
      print('🎯 Punkt testowy: $leftBottomPoint');

      final gesture3 = await tester.startGesture(leftBottomPoint);
      await tester.pump(const Duration(milliseconds: 200));
      print('📍 Gesture rozpoczęty na dolnym rogu');

      await gesture3.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      print('⬅️ Średnie przesunięcie o -30px');

      await gesture3.up();
      await tester.pumpAndSettle();
      print('🔚 Gesture 3 zakończony');

      // SPRAWDZENIE WYNIKÓW
      print('');
      print('📊 ANALIZA WYNIKÓW:');
      final finalRect = tester.getRect(widgetFinder);
      print('📐 Widget rect po testach: $finalRect');

      final originalItem =
          controller.items.firstWhere((id) => id == 'test_widget');
      print('🔍 Original item ID: $originalItem');

      // Check if widget changed size or position
      if (finalRect.width != widgetRect.width) {
        print(
            '✅ RESIZE ZADZIAŁAŁ: szerokość zmieniła się z ${widgetRect.width} na ${finalRect.width}');
      } else {
        print('❌ RESIZE NIE ZADZIAŁAŁ: szerokość nadal ${finalRect.width}');
        print('🚨 PROBLEM: Resize na lewej krawędzi nie reaguje!');
      }

      if (finalRect.left != widgetRect.left) {
        print(
            '✅ POZYCJA ZMIENIŁA SIĘ: left z ${widgetRect.left} na ${finalRect.left}');
      } else {
        print('❌ POZYCJA BEZ ZMIAN: left nadal ${finalRect.left}');
      }
    });

    testWidgets('🔬 Porównanie: resize z prawej krawędzi (powinien działać)',
        (WidgetTester tester) async {
      print('📋 Test kontrolny: resize z prawej krawędzi');

      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(
          identifier: 'test_widget_right',
          width: 2,
          height: 1,
          startX: 2, // Różna pozycja dla odróżnienia
          startY: 0,
          minWidth: 1,
        ),
      ]);

      final virtualConfig = VirtualColumnsConfig.visible(
        disabledColumns: [1, 4],
        disabledColumnWidth: 0.08,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    border: Border.all(color: Colors.red, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      'RIGHT TEST\n(${item.layoutData.startX}-${item.layoutData.startX + item.layoutData.width - 1})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                dashboardItemController: controller,
                slotCount: 6,
                slotHeight: 100,
                virtualColumnsConfig: virtualConfig,
                editModeSettings: EditModeSettings(
                  resizeCursorSide: 25,
                  longPressEnabled: true,
                  panEnabled: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final widgetFinder = find.text('RIGHT TEST\n(2-3)');
      expect(widgetFinder, findsOneWidget);

      await tester.longPress(widgetFinder);
      await tester.pumpAndSettle();
      print('👆 Edit mode aktywowany dla testu prawej krawędzi');

      final widgetRect = tester.getRect(widgetFinder);
      print('📐 Prawa krawędź - original rect: $widgetRect');

      // Test resize z prawej krawędzi
      final rightPoint = Offset(widgetRect.right - 5, widgetRect.center.dy);
      print('🎯 Punkt na prawej krawędzi: $rightPoint');

      final gesture = await tester.startGesture(rightPoint);
      await tester.pump(const Duration(milliseconds: 200));

      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 100));
      print('➡️ Resize w prawo o +40px');

      await gesture.up();
      await tester.pumpAndSettle();

      final finalRect = tester.getRect(widgetFinder);
      print('📐 Prawa krawędź - final rect: $finalRect');

      if (finalRect.width > widgetRect.width) {
        print('✅ RESIZE Z PRAWEJ DZIAŁA: szerokość zwiększyła się');
      } else {
        print('❌ RESIZE Z PRAWEJ TEŻ NIE DZIAŁA: problem może być głębszy');
      }
    });

    test('💡 Analiza możliwych przyczyn problemu', () {
      print('📋 Możliwe przyczyny dlaczego fix nie działa:');
      print('');
      print('1. 🔍 DETECTION PROBLEM:');
      print('   - Może obszar resize nie jest poprawnie wykrywany');
      print('   - Hit testing może nie rozpoznawać lewej krawędzi');
      print('   - ResizeCursorSide może nie działać z virtual columns');
      print('');
      print('2. 🎯 GESTURE RECOGNITION:');
      print('   - Pan gesture może nie być rozpoznawany');
      print('   - Może konflikty z long press detection');
      print('   - Virtual columns mogą wpływać na gesture area');
      print('');
      print('3. 🧮 CALCULATION ISSUES:');
      print('   - Może inne miejsca w kodzie używają _slotEdge');
      print('   - Position calculation może być niepoprawny');
      print('   - Może problem z boundary detection');
      print('');
      print('4. 🎨 RENDERING ISSUES:');
      print('   - Widget może być renderowany w złej pozycji');
      print('   - Resize handles mogą być w złym miejscu');
      print('   - Visual feedback może być błędny');
      print('');
      print('🔧 NASTĘPNE KROKI:');
      print('   - Sprawdzić gesture detection w virtual columns');
      print('   - Zbadać wszystkie użycia _slotEdge w kodzie');
      print('   - Sprawdzić czy resize handles są poprawnie pozycjonowane');

      expect(true, isTrue,
          reason: 'Analiza przeprowadzona - potrzebne głębsze badanie');
    });

    testWidgets(
        '🔍 Bug w adjustResizeOffset - używa _slotEdge zamiast rzeczywistej szerokości',
        (WidgetTester tester) async {
      print('🐛 Test: Problem w adjustResizeOffset z virtual columns');

      // Ustawienia z virtual columns gdzie kolumna 1 i 2 mają inne szerokości
      final virtualConfig = VirtualColumnsConfig.visible(
        disabledColumns: [1, 2],
        disabledColumnWidth: 0.05, // 5% szerokości
      );

      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(
          identifier: 'test_widget',
          width: 2,
          height: 1,
          startX: 3, // Widget zaczyna w kolumnie 3
          startY: 0,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: Dashboard<DashboardItem>(
                itemBuilder: (item) => Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      'Widget ${item.layoutData.startX}-${item.layoutData.startX + item.layoutData.width - 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                dashboardItemController: controller,
                slotCount: 6,
                slotHeight: 100,
                virtualColumnsConfig: virtualConfig,
                editModeSettings: EditModeSettings(
                  resizeCursorSide: 20,
                  longPressEnabled: true,
                  panEnabled: true,
                  paintBackgroundLines: true,
                  fillEditingBackground: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final widgetFinder = find.text('Widget 3-4');
      expect(widgetFinder, findsOneWidget);

      // Aktywuj edit mode
      await tester.longPress(widgetFinder);
      await tester.pumpAndSettle();

      final widgetRect = tester.getRect(widgetFinder);
      final leftEdgePoint = Offset(widgetRect.left + 5, widgetRect.center.dy);

      print('📊 ANALIZA PROBLEMU:');
      print('   Kolumny 1,2: wyłączone (5% szerokości każda)');
      print('   Kolumny 0,3,4,5: normalne');
      print('   Widget: kolumny 3-4');
      print(
          '   _slotEdge: średnia szerokość enabled columns (~150px dla 600px grid)');
      print('   Rzeczywista szerokość kolumny 3: ~150px');
      print(
          '   adjustResizeOffset używa _slotEdge zamiast rzeczywistej szerokości');
      print('');

      // Test resize w lewo
      final gesture = await tester.startGesture(leftEdgePoint);

      // Małe przesunięcie - powinno pozostać w range smooth resize
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 50));

      print('🚨 PROBLEM: adjustResizeOffset(slotEdge, ...) używa:');
      print('   slotEdge = _slotEdge (~150px)');
      print('   Ale powinien używać rzeczywistej szerokości kolumny 3');

      // Większe przesunięcie - próba przeskoku do next resize slot
      await gesture.moveBy(const Offset(-140, 0)); // Blisko _slotEdge threshold
      await tester.pump(const Duration(milliseconds: 50));

      await gesture.up();
      await tester.pumpAndSettle();

      print('');
      print('💡 ROOT CAUSE:');
      print('   1. _resizeMove() poprawnie używa getColumnWidth()');
      print(
          '   2. _clampDifLeft() poprawnie kalkuluje z rzeczywistymi szerokościami');
      print('   3. ALE: adjustResizeOffset() używa stały _slotEdge parameter');
      print('   4. To powoduje błędne przesunięcia w virtual columns layout');
      print('');
      print('🔧 WYMAGANA NAPRAWA:');
      print('   adjustResizeOffset() musi brać pod uwagę rzeczywiste');
      print(
          '   szerokości kolumn dla AxisDirection.left i AxisDirection.right');
    });
  });
}
