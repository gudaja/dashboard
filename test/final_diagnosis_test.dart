import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dashboard/dashboard.dart';

void main() {
  group(
      '🔬 OSTATECZNA DIAGNOZA: Dokładne testowanie wszystkich kierunków resize',
      () {
    testWidgets('🎯 Test wszystkich kierunków resize z virtual columns',
        (WidgetTester tester) async {
      print('🔬 OSTATECZNA DIAGNOZA - TEST WSZYSTKICH KIERUNKÓW');
      print('');

      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(
          identifier: 'test_widget',
          width: 2,
          height: 2,
          startX: 2, // Środek gridu - kolumny 2-3
          startY: 1, // Środek gridu - wiersze 1-2
          minWidth: 1,
          minHeight: 1,
        ),
      ]);

      final virtualConfig = VirtualColumnsConfig.visible(
        disabledColumns: [0, 4],
        disabledColumnWidth: 0.1, // 10% szerokości każda
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
                    color: Colors.red,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      'TEST ALL\n(${item.layoutData.startX}-${item.layoutData.startX + item.layoutData.width - 1})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
                  resizeCursorSide: 20,
                  longPressEnabled: true,
                  panEnabled: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      print('✅ Dashboard załadowany');

      final widgetFinder = find.text('TEST ALL\n(2-3)');
      expect(widgetFinder, findsOneWidget);

      await tester.longPress(widgetFinder);
      await tester.pumpAndSettle();
      print('👆 Edit mode aktywowany');

      final originalRect = tester.getRect(widgetFinder);
      print('📐 Original rect: $originalRect');
      print('   Szerokość: ${originalRect.width}');
      print('   Wysokość: ${originalRect.height}');
      print('   Left: ${originalRect.left}');
      print('   Right: ${originalRect.right}');
      print('   Top: ${originalRect.top}');
      print('   Bottom: ${originalRect.bottom}');
      print('');

      // TEST 1: LEWA STRONA
      print('🔍 TEST 1: RESIZE Z LEWEJ STRONY');
      final leftPoint = Offset(originalRect.left + 5, originalRect.center.dy);
      print('   Punkt: $leftPoint');

      final leftGesture = await tester.startGesture(leftPoint);
      await tester.pump(const Duration(milliseconds: 100));
      await leftGesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await leftGesture.up();
      await tester.pumpAndSettle();

      final afterLeftRect = tester.getRect(widgetFinder);
      bool leftWorked = (afterLeftRect != originalRect);
      print('   ✅ Czy zadziałało? $leftWorked');
      if (leftWorked) {
        print(
            '   📊 Zmiana: width ${originalRect.width} → ${afterLeftRect.width}');
        print(
            '   📊 Zmiana: left ${originalRect.left} → ${afterLeftRect.left}');
      }
      print('');

      // TEST 2: PRAWA STRONA
      print('🔍 TEST 2: RESIZE Z PRAWEJ STRONY');
      final rightPoint =
          Offset(afterLeftRect.right - 5, afterLeftRect.center.dy);
      print('   Punkt: $rightPoint');

      final rightGesture = await tester.startGesture(rightPoint);
      await tester.pump(const Duration(milliseconds: 100));
      await rightGesture.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await rightGesture.up();
      await tester.pumpAndSettle();

      final afterRightRect = tester.getRect(widgetFinder);
      bool rightWorked = (afterRightRect != afterLeftRect);
      print('   ✅ Czy zadziałało? $rightWorked');
      if (rightWorked) {
        print(
            '   📊 Zmiana: width ${afterLeftRect.width} → ${afterRightRect.width}');
        print(
            '   📊 Zmiana: right ${afterLeftRect.right} → ${afterRightRect.right}');
      }
      print('');

      // TEST 3: GÓRA
      print('🔍 TEST 3: RESIZE Z GÓRY');
      final topPoint = Offset(afterRightRect.center.dx, afterRightRect.top + 5);
      print('   Punkt: $topPoint');

      final topGesture = await tester.startGesture(topPoint);
      await tester.pump(const Duration(milliseconds: 100));
      await topGesture.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 100));
      await topGesture.up();
      await tester.pumpAndSettle();

      final afterTopRect = tester.getRect(widgetFinder);
      bool topWorked = (afterTopRect != afterRightRect);
      print('   ✅ Czy zadziałało? $topWorked');
      if (topWorked) {
        print(
            '   📊 Zmiana: height ${afterRightRect.height} → ${afterTopRect.height}');
        print('   📊 Zmiana: top ${afterRightRect.top} → ${afterTopRect.top}');
      }
      print('');

      // TEST 4: DÓŁ
      print('🔍 TEST 4: RESIZE Z DOŁU');
      final bottomPoint =
          Offset(afterTopRect.center.dx, afterTopRect.bottom - 5);
      print('   Punkt: $bottomPoint');

      final bottomGesture = await tester.startGesture(bottomPoint);
      await tester.pump(const Duration(milliseconds: 100));
      await bottomGesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 100));
      await bottomGesture.up();
      await tester.pumpAndSettle();

      final finalRect = tester.getRect(widgetFinder);
      bool bottomWorked = (finalRect != afterTopRect);
      print('   ✅ Czy zadziałało? $bottomWorked');
      if (bottomWorked) {
        print(
            '   📊 Zmiana: height ${afterTopRect.height} → ${finalRect.height}');
        print(
            '   📊 Zmiana: bottom ${afterTopRect.bottom} → ${finalRect.bottom}');
      }
      print('');

      // PODSUMOWANIE
      print('📋 PODSUMOWANIE WYNIKÓW:');
      print('   ⬅️ Lewa strona:   ${leftWorked ? "✅ DZIAŁA" : "❌ NIE DZIAŁA"}');
      print(
          '   ➡️ Prawa strona:  ${rightWorked ? "✅ DZIAŁA" : "❌ NIE DZIAŁA"}');
      print('   ⬆️ Góra:          ${topWorked ? "✅ DZIAŁA" : "❌ NIE DZIAŁA"}');
      print(
          '   ⬇️ Dół:           ${bottomWorked ? "✅ DZIAŁA" : "❌ NIE DZIAŁA"}');
      print('');

      if (!leftWorked && rightWorked && topWorked && bottomWorked) {
        print('🎯 DIAGNOZA: Tylko lewa strona nie działa - user mówi prawdę!');
      } else if (!leftWorked && !rightWorked && !topWorked && !bottomWorked) {
        print(
            '🚨 DIAGNOZA: Żaden kierunek nie działa - problem z całym systemem resize');
      } else {
        print('🔍 DIAGNOZA: Mieszane wyniki - problem częściowy');
      }

      print('');
      print('📐 RECT PROGRESSION:');
      print('   Original: $originalRect');
      print('   Po left:  $afterLeftRect');
      print('   Po right: $afterRightRect');
      print('   Po top:   $afterTopRect');
      print('   Final:    $finalRect');
    });

    testWidgets('🧪 PORÓWNANIE: bez virtual columns (kontrola)',
        (WidgetTester tester) async {
      print('');
      print('🧪 TEST KONTROLNY: BEZ VIRTUAL COLUMNS');

      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(
          identifier: 'control_widget',
          width: 2,
          height: 2,
          startX: 2,
          startY: 1,
          minWidth: 1,
          minHeight: 1,
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
                    color: Colors.green,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      'CONTROL\n(${item.layoutData.startX}-${item.layoutData.startX + item.layoutData.width - 1})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                dashboardItemController: controller,
                slotCount: 6,
                slotHeight: 100,
                // Brak virtualColumnsConfig
                editModeSettings: EditModeSettings(
                  resizeCursorSide: 20,
                  longPressEnabled: true,
                  panEnabled: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final widgetFinder = find.text('CONTROL\n(2-3)');
      expect(widgetFinder, findsOneWidget);

      await tester.longPress(widgetFinder);
      await tester.pumpAndSettle();

      final originalRect = tester.getRect(widgetFinder);

      // Test tylko lewej strony dla szybkości
      final leftPoint = Offset(originalRect.left + 5, originalRect.center.dy);
      final leftGesture = await tester.startGesture(leftPoint);
      await tester.pump(const Duration(milliseconds: 100));
      await leftGesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await leftGesture.up();
      await tester.pumpAndSettle();

      final afterLeftRect = tester.getRect(widgetFinder);
      bool leftWorked = (afterLeftRect != originalRect);

      print('📋 WYNIK KONTROLNY:');
      print(
          '   ⬅️ Lewa strona bez virtual columns: ${leftWorked ? "✅ DZIAŁA" : "❌ NIE DZIAŁA"}');

      if (leftWorked) {
        print(
            '   📊 Potwierdza że mechanizm resize działa gdy nie ma virtual columns');
      } else {
        print(
            '   🚨 Problem może być w całym systemie resize, nie tylko virtual columns');
      }
    });
  });
}
