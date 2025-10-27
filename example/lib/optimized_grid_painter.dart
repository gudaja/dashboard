import 'package:flutter/material.dart';

/// Wydajny CustomPainter dla siatki dashboardu
/// Zamiast tworzyć wiele Container'ów z borderami, rysuje siatkę w jednym custom painter
class OptimizedGridPainter extends CustomPainter {
  final int slotCount;
  final double slotWidth;
  final double slotHeight;
  final double horizontalSpace;
  final double verticalSpace;
  final Color lineColor;
  final double lineWidth;
  final double borderRadius;
  final Set<int>? disabledColumns;

  const OptimizedGridPainter({
    required this.slotCount,
    required this.slotWidth,
    required this.slotHeight,
    required this.horizontalSpace,
    required this.verticalSpace,
    this.lineColor = Colors.black12,
    this.lineWidth = 0.5,
    this.borderRadius = 5.0,
    this.disabledColumns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Oblicz ile rzędów potrzebujemy do narysowania
    final rowCount = (size.height / slotHeight).ceil();

    // Narysuj wszystkie sloty
    for (int y = 0; y < rowCount; y++) {
      for (int x = 0; x < slotCount; x++) {
        // Pomiń wyłączone kolumny
        if (disabledColumns?.contains(x) ?? false) {
          continue;
        }

        final left = x * slotWidth + horizontalSpace / 2;
        final top = y * slotHeight + verticalSpace / 2;
        final width = slotWidth - horizontalSpace;
        final height = slotHeight - verticalSpace;

        // Rysuj prostokąt z zaokrąglonymi rogami
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          Radius.circular(borderRadius),
        );

        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OptimizedGridPainter oldDelegate) {
    return slotCount != oldDelegate.slotCount ||
        slotWidth != oldDelegate.slotWidth ||
        slotHeight != oldDelegate.slotHeight ||
        horizontalSpace != oldDelegate.horizontalSpace ||
        verticalSpace != oldDelegate.verticalSpace ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth ||
        borderRadius != oldDelegate.borderRadius ||
        disabledColumns != oldDelegate.disabledColumns;
  }
}

/// Widget wrapper dla OptimizedGridPainter
class OptimizedGridBackground extends StatelessWidget {
  final int slotCount;
  final double slotWidth;
  final double slotHeight;
  final double horizontalSpace;
  final double verticalSpace;
  final Color lineColor;
  final double lineWidth;
  final double borderRadius;
  final Set<int>? disabledColumns;

  const OptimizedGridBackground({
    super.key,
    required this.slotCount,
    required this.slotWidth,
    required this.slotHeight,
    required this.horizontalSpace,
    required this.verticalSpace,
    this.lineColor = Colors.black12,
    this.lineWidth = 0.5,
    this.borderRadius = 5.0,
    this.disabledColumns,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: OptimizedGridPainter(
          slotCount: slotCount,
          slotWidth: slotWidth,
          slotHeight: slotHeight,
          horizontalSpace: horizontalSpace,
          verticalSpace: verticalSpace,
          lineColor: lineColor,
          lineWidth: lineWidth,
          borderRadius: borderRadius,
          disabledColumns: disabledColumns,
        ),
        child: Container(),
      ),
    );
  }
}
