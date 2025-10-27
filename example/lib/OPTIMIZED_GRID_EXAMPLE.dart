// ignore_for_file: dangling_library_doc_comments, file_names

/// PRZYKŁAD: Jak użyć OptimizedGridPainter dla jeszcze lepszej wydajności
///
/// To jest OPCJONALNA optymalizacja - obecne cache'owanie już daje dobrą wydajność.
/// Użyj tego tylko jeśli masz bardzo dużą siatkę (>30 kolumn) lub nadal widzisz problemy.
///
/// UWAGA: Ten kod NIE jest jeszcze zintegrowany z główną aplikacją.
/// To jest tylko przykład jak można by to zrobić.

import 'package:flutter/material.dart';
import 'package:dashboard/dashboard.dart';
import 'package:example/optimized_grid_painter.dart';

/// Przykładowa implementacja z OptimizedGridPainter
///
/// Zamiast używać slotBackgroundBuilder (który tworzy wiele Container'ów),
/// ta wersja używa jednego CustomPainter dla całej siatki.
class OptimizedDashboardExample extends StatelessWidget {
  const OptimizedDashboardExample({
    super.key,
    required this.itemController,
    required this.slotCount,
  });

  final DashboardItemController itemController;
  final int slotCount;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final slotWidth = (width - 16) / slotCount; // subtract padding
    final slotHeight = slotWidth; // aspect ratio 1:1

    return Stack(
      children: [
        // Wydajne tło siatki - jedna operacja paint zamiast setek
        Positioned.fill(
          child: OptimizedGridBackground(
            slotCount: slotCount,
            slotWidth: slotWidth,
            slotHeight: slotHeight,
            horizontalSpace: 8,
            verticalSpace: 8,
            lineColor: Colors.black12,
            lineWidth: 0.5,
            borderRadius: 5.0,
            disabledColumns: {6, 13}, // przykładowe wyłączone kolumny
          ),
        ),

        // Dashboard bez slotBackgroundBuilder
        Dashboard(
          dashboardItemController: itemController,
          slotCount: slotCount,
          padding: const EdgeInsets.all(8),
          horizontalSpace: 8,
          verticalSpace: 8,
          slotAspectRatio: 1,

          // USUŃ slotBackgroundBuilder - używamy OptimizedGridBackground powyżej
          // slotBackgroundBuilder: null,

          itemStyle: ItemStyle(
            color: Colors.transparent,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          itemBuilder: (item) {
            return Container(
              color: Colors.blue,
              child: Center(
                child: Text('Item ${item.identifier}'),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Alternatywna wersja - z dynamicznym tłem podczas scrollowania
///
/// Ta wersja używa scroll controller do aktualizacji tła tylko gdy potrzeba
class ScrollOptimizedDashboardExample extends StatefulWidget {
  const ScrollOptimizedDashboardExample({
    super.key,
    required this.itemController,
    required this.slotCount,
  });

  final DashboardItemController itemController;
  final int slotCount;

  @override
  State<ScrollOptimizedDashboardExample> createState() =>
      _ScrollOptimizedDashboardExampleState();
}

class _ScrollOptimizedDashboardExampleState
    extends State<ScrollOptimizedDashboardExample> {
  final ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dashboard(
      scrollController: scrollController,
      dashboardItemController: widget.itemController,
      slotCount: widget.slotCount,
      padding: const EdgeInsets.all(8),
      horizontalSpace: 8,
      verticalSpace: 8,
      slotAspectRatio: 1,

      // Użyj prostego slotBackgroundBuilder z cache'owaniem
      // (już zaimplementowane w dashboard_stack.dart)
      slotBackgroundBuilder: SlotBackgroundBuilder.withDimensionsFunction(
        (context, item, x, y, editing, slotW, slotH, virtualConfig) {
          final isDisabled = virtualConfig?.isColumnDisabled(x) ?? false;
          if (isDisabled) return null;

          // Prosty, cache'owany widget
          return RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12, width: 0.5),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          );
        },
      ),

      itemStyle: ItemStyle(
        color: Colors.transparent,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      itemBuilder: (item) {
        return Container(
          color: Colors.green,
          child: Center(
            child: Text('Item ${item.identifier}'),
          ),
        );
      },
    );
  }
}

/// UWAGI IMPLEMENTACYJNE:
/// 
/// 1. OptimizedGridPainter jest najszybszy gdy:
///    - Masz dużą siatkę (>20 kolumn)
///    - Wszystkie sloty wyglądają tak samo
///    - Nie potrzebujesz różnych kolorów dla różnych slotów
/// 
/// 2. Obecne cache'owanie (już zaimplementowane) jest wystarczające gdy:
///    - Masz normalną siatkę (<30 kolumn)
///    - Możesz potrzebować różnych stylów dla różnych slotów
///    - Chcesz prostszą implementację
/// 
/// 3. Benchmark przed i po:
///    - Użyj Flutter DevTools Performance
///    - Zmierz "Build time" i "Paint time"
///    - Sprawdź "Frame rendering time"
/// 
/// 4. Wybór optymalizacji:
///    - Dla większości przypadków: użyj cache'owania (już zrobione)
///    - Dla bardzo dużych siatek: użyj OptimizedGridPainter
///    - Dla małych siatek (<10 kolumn): nie ma znaczenia

