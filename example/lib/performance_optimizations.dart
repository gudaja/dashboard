import 'package:flutter/material.dart';

/// Pomocne klasy do optymalizacji wydajności w Dashboard

/// RepaintBoundary wrapper dla elementów Dashboard
class PerformantDashboardItem extends StatelessWidget {
  const PerformantDashboardItem({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: child,
    );
  }
}

/// Optimized SlotBackground z caching
class CachedSlotBackground<T> extends StatelessWidget {
  const CachedSlotBackground({
    super.key,
    required this.child,
    required this.cacheKey,
  });

  final Widget child;
  final String cacheKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: ValueKey(cacheKey),
      child: child,
    );
  }
}

/// Memoized widget builder do redukcji niepotrzebnych rebuilds
class MemoizedBuilder<T> extends StatefulWidget {
  const MemoizedBuilder({
    super.key,
    required this.value,
    required this.builder,
  });

  final T value;
  final Widget Function(T value) builder;

  @override
  State<MemoizedBuilder<T>> createState() => _MemoizedBuilderState<T>();
}

class _MemoizedBuilderState<T> extends State<MemoizedBuilder<T>> {
  T? _lastValue;
  Widget? _cachedWidget;

  @override
  Widget build(BuildContext context) {
    if (_lastValue != widget.value) {
      _lastValue = widget.value;
      _cachedWidget = widget.builder(widget.value);
    }
    return _cachedWidget!;
  }
}

/// Optimized Container z precomputed decorations
class OptimizedDashboardContainer extends StatelessWidget {
  const OptimizedDashboardContainer({
    super.key,
    required this.color,
    required this.child,
    this.borderRadius = 10.0,
  });

  final Color color;
  final Widget child;
  final double borderRadius;

  static final Map<String, BoxDecoration> _decorationCache = {};

  BoxDecoration _getDecoration() {
    final key = '${color.toARGB32()}_$borderRadius';
    return _decorationCache.putIfAbsent(
      key,
      () => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      decoration: _getDecoration(),
      child: child,
    );
  }
}

/// Performance utilities
class DashboardPerformanceUtils {
  /// Używaj tego do wrap'owania expensive widgets
  static Widget withRepaintBoundary(Widget child) {
    return RepaintBoundary(child: child);
  }

  /// Tworzy optimized text widget
  static Widget createOptimizedText(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.white),
      maxLines: null,
      overflow: TextOverflow.visible,
    );
  }

  /// Sprawdza czy widget powinien być rebuilt
  static bool shouldRebuild<T>(T? oldValue, T newValue) {
    return oldValue != newValue;
  }

  /// Tworzy cached key dla widget
  static String createCacheKey(List<dynamic> components) {
    return components.map((e) => e.toString()).join('_');
  }
}

/// Ultra-wydajny painter dla slot backgrounds - maluje całą siatkę naraz
class PerformantSlotBackgroundPainter extends CustomPainter {
  final double slotWidth;
  final double slotHeight;
  final int slotCount;
  final int rowCount;
  final double horizontalSpace;
  final double verticalSpace;
  final EdgeInsets padding;
  final Set<int>? disabledColumns;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final dynamic virtualConfig;
  final double? totalWidth;

  PerformantSlotBackgroundPainter({
    required this.slotWidth,
    required this.slotHeight,
    required this.slotCount,
    required this.rowCount,
    required this.horizontalSpace,
    required this.verticalSpace,
    required this.padding,
    this.disabledColumns,
    this.borderColor = Colors.black,
    this.borderWidth = 2.0,
    this.borderRadius = 5.0,
    this.virtualConfig,
    this.totalWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    for (int y = 0; y < rowCount; y++) {
      double top = padding.top + y * (slotHeight + verticalSpace);
      double left = padding.left;
      for (int x = 0; x < slotCount; x++) {
        double width = virtualConfig != null && totalWidth != null
            ? virtualConfig.getColumnWidth(x, slotWidth, totalWidth!)
            : slotWidth;
        if (disabledColumns == null ||
            !(disabledColumns?.contains(x) ?? false)) {
          final rect = Rect.fromLTWH(left, top, width, slotHeight);
          final rrect =
              RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
          canvas.drawRRect(rrect, borderPaint);
        }
        left += width + horizontalSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Utility klasa dla wydajnych slot backgrounds
class PerformantSlotBackgroundUtils {
  static Widget createSlotBackgroundOverlay({
    required double slotWidth,
    required double slotHeight,
    required int slotCount,
    required int rowCount,
    required double horizontalSpace,
    required double verticalSpace,
    required EdgeInsets padding,
    Set<int>? disabledColumns,
    Color borderColor = Colors.black,
    double borderWidth = 2.0,
    double borderRadius = 5.0,
    dynamic virtualConfig,
    double? totalWidth,
  }) {
    return CustomPaint(
      painter: PerformantSlotBackgroundPainter(
        slotWidth: slotWidth,
        slotHeight: slotHeight,
        slotCount: slotCount,
        rowCount: rowCount,
        horizontalSpace: horizontalSpace,
        verticalSpace: verticalSpace,
        padding: padding,
        disabledColumns: disabledColumns,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        virtualConfig: virtualConfig,
        totalWidth: totalWidth,
      ),
      size: Size.infinite,
    );
  }
}
