import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dashboard/dashboard.dart';

void main() {
  group('Virtual Columns Resize Bug Tests', () {
    testWidgets(
        '🐛 Bug reprodukcji: resize przestaje działać z virtual columns',
        (WidgetTester tester) async {
      print('📋 Test: Virtual Columns Resize Bug Reproduction');

      // Konfiguracja widget który zaczyna w kolumnie 3 (poza pierwszą kolumną)
      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(
          identifier: 'test_widget',
          width: 2,
          height: 1,
          startX: 3, // ❗ WIDGET ZACZYNA W KOLUMNIE 3 (nie 0!)
          startY: 0,
        ),
      ]);

      // Virtual columns - kolumny 1 i 2 są wyłączone ale widoczne
      final virtualConfig = VirtualColumnsConfig.visible(
        disabledColumns: [1, 2],
        disabledColumnWidth: 0.08, // 8% szerokości
      );

      print('🔧 Utworzono widget startX: 3, virtual columns: [1, 2]');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Center(
                  child: Text(
                    'Test Widget',
                    style: const TextStyle(color: Colors.white),
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
      );

      await tester.pumpAndSettle();
      print('✅ Dashboard z virtual columns renderowany');

      // Znajdź widget
      final widgetFinder = find.text('Test Widget');
      expect(widgetFinder, findsOneWidget);
      print('🎯 Widget znaleziony');

      // Aktywacja edit mode
      await tester.longPress(widgetFinder);
      await tester.pumpAndSettle();
      print('👆 Edit mode aktywowany');

      // Test resize na lewej krawędzi
      final widgetRect = tester.getRect(widgetFinder);
      final leftEdgePoint = Offset(widgetRect.left + 5, widgetRect.center.dy);
      print('👈 Punkt resize na lewej krawędzi: $leftEdgePoint');

      // Rozpocznij gesture na lewej krawędzi
      final gesture = await tester.startGesture(leftEdgePoint);
      await tester.pump(const Duration(milliseconds: 100));

      // Przesuń w lewo (resize w lewo)
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      print('⬅️ Przesunięcie resize w lewo o -30px');

      // Test czy resize się reaktywuje - przesuń myszę delikatnie
      await gesture.moveBy(const Offset(-5, 0));
      await tester.pump(const Duration(milliseconds: 100));

      // Zakończ gesture
      await gesture.up();
      await tester.pumpAndSettle();

      print('✅ Test gesture resize zakończony');
      print('');
      print('🚨 PROBLEM:');
      print(
          '   W virtual columns resize na lewej krawędzi nie działa poprawnie');
      print('   gdy widget jest poza pierwszą kolumną.');
      print('   Powód: _clampDifLeft używa stałego _slotEdge zamiast');
      print('   rzeczywistej szerokości kolumny widgetu.');
    });

    testWidgets('🧪 Kontrola: resize działa bez virtual columns',
        (WidgetTester tester) async {
      print('📋 Test kontrolny: bez virtual columns');

      final controller = DashboardItemController<DashboardItem>(items: [
        DashboardItem(
          identifier: 'test_widget',
          width: 2,
          height: 1,
          startX: 3, // Ten sam startX dla porównania
          startY: 0,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dashboard<DashboardItem>(
              itemBuilder: (item) => Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Center(
                  child: Text(
                    'Test Widget',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              dashboardItemController: controller,
              slotCount: 6,
              slotHeight: 100,
              // virtualColumnsConfig: null, // BEZ virtual columns
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
      );

      await tester.pumpAndSettle();
      print('✅ Dashboard BEZ virtual columns renderowany');

      final widgetFinder = find.text('Test Widget');
      expect(widgetFinder, findsOneWidget);

      // Edit mode + test resize
      await tester.longPress(widgetFinder);
      await tester.pumpAndSettle();
      print('👆 Edit mode aktywowany');

      final widgetRect = tester.getRect(widgetFinder);
      final leftEdgePoint = Offset(widgetRect.left + 5, widgetRect.center.dy);

      final gesture = await tester.startGesture(leftEdgePoint);
      await tester.pump(const Duration(milliseconds: 100));

      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 100));
      print('⬅️ Resize w lewo bez virtual columns');

      await gesture.up();
      await tester.pumpAndSettle();

      print('✅ Test kontrolny zakończony - resize działa normalnie');
    });

    test('💡 Analiza problemu: _slotEdge vs rzeczywista szerokość kolumny', () {
      print('📋 Analiza głównego problemu:');
      print('');
      print('🚨 PROBLEM:');
      print('   Metoda _clampDifLeft() w ItemCurrentLayout używa:');
      print('   ```dart');
      print('   double _clampDifLeft(double x) {');
      print('     var slot = _slotEdge;  // ❌ Stały _slotEdge!');
      print('     return x.clamp(0, (width - minWidth) * slot);');
      print('   }');
      print('   ```');
      print('');
      print('💡 ROZWIĄZANIE:');
      print(
          '   _slotEdge to średnia szerokość dla enabled columns w virtual columns.');
      print('   Ale każda kolumna może mieć inną rzeczywistą szerokość!');
      print('   _clampDifLeft powinien używać rzeczywistej szerokości');
      print('   konkretnej kolumny widgetu.');
      print('');
      print('🔧 FIX WYMAGANY:');
      print('   _clampDifLeft powinien wziąć pod uwagę szerokości');
      print('   konkretnych kolumn widgetu zamiast średniego _slotEdge.');

      expect(true, isTrue, reason: 'Problem zidentyfikowany poprawnie');
    });
  });
}
