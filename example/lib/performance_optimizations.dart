import 'package:flutter/material.dart';
import 'package:dashboard/dashboard.dart';

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

/// Wydajny CustomPainter dla Dashboard items - eliminuje Canvas.saveLayer calls
class DashboardItemPainter extends CustomPainter {
  final Color backgroundColor;
  final double borderRadius;
  final bool showShadow;

  DashboardItemPainter({
    required this.backgroundColor,
    required this.borderRadius,
    this.showShadow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Maluj cień najpierw (jeśli potrzebny) - bez saveLayer
    if (showShadow) {
      final shadowPaint = Paint()
        ..color = const Color(0x1A000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      final shadowRect = rect.translate(0, 1);
      final shadowRRect =
          RRect.fromRectAndRadius(shadowRect, Radius.circular(borderRadius));
      canvas.drawRRect(shadowRRect, shadowPaint);
    }

    // Maluj tło w jednym przejściu
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rrect, backgroundPaint);
  }

  @override
  bool shouldRepaint(DashboardItemPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        borderRadius != oldDelegate.borderRadius ||
        showShadow != oldDelegate.showShadow;
  }
}

/// Wysoko-wydajny widget dashboard item używający CustomPainter
class PerformantPaintedDashboardItem extends StatelessWidget {
  const PerformantPaintedDashboardItem({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = 10.0,
    this.showShadow = true,
  });

  final Widget child;
  final Color color;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: DashboardItemPainter(
          backgroundColor: color,
          borderRadius: borderRadius,
          showShadow: showShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: child,
        ),
      ),
    );
  }
}

/// Zaawansowany painter który maluje wszystko bezpośrednio na canvas
class CompoundDashboardPainter extends CustomPainter {
  final Color backgroundColor;
  final double borderRadius;
  final String text;
  final TextStyle textStyle;
  final bool showShadow;
  final IconData? icon;
  final Color? iconColor;

  // Cache dla text layouts
  static final Map<String, TextPainter> _textCache = {};

  CompoundDashboardPainter({
    required this.backgroundColor,
    required this.borderRadius,
    required this.text,
    required this.textStyle,
    this.showShadow = true,
    this.icon,
    this.iconColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Maluj cień (jeśli potrzebny)
    if (showShadow) {
      final shadowPaint = Paint()
        ..color = const Color(0x1A000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      final shadowRect = rect.translate(0, 1);
      final shadowRRect =
          RRect.fromRectAndRadius(shadowRect, Radius.circular(borderRadius));
      canvas.drawRRect(shadowRRect, shadowPaint);
    }

    // 2. Maluj tło
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, backgroundPaint);

    // 3. Maluj tekst bezpośrednio na canvas
    final textKey = '${text}_${textStyle.fontSize}_${textStyle.color}';
    TextPainter textPainter = _textCache[textKey] ?? _createTextPainter();
    _textCache[textKey] = textPainter;

    // Wycentruj tekst
    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, textOffset);

    // 4. Maluj ikonę (jeśli jest)
    if (icon != null) {
      _paintIcon(canvas, size);
    }
  }

  TextPainter _createTextPainter() {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    return textPainter;
  }

  void _paintIcon(Canvas canvas, Size size) {
    if (icon == null) return;

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon!.codePoint),
        style: TextStyle(
          fontSize: 24,
          fontFamily: icon!.fontFamily,
          color: iconColor ?? Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    iconPainter.layout();

    // Umieść ikonę w prawym górnym rogu
    final iconOffset = Offset(
      size.width - iconPainter.width - 10,
      10,
    );

    iconPainter.paint(canvas, iconOffset);
  }

  @override
  bool shouldRepaint(CompoundDashboardPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        borderRadius != oldDelegate.borderRadius ||
        text != oldDelegate.text ||
        textStyle != oldDelegate.textStyle ||
        showShadow != oldDelegate.showShadow ||
        icon != oldDelegate.icon ||
        iconColor != oldDelegate.iconColor;
  }

  // Wyczyść cache gdy za duży
  static void clearCache() {
    if (_textCache.length > 50) {
      _textCache.clear();
    }
  }
}

/// Ultra-wydajny widget używający compound painter
class UltraPerformantDashboardItem extends StatelessWidget {
  const UltraPerformantDashboardItem({
    super.key,
    required this.color,
    required this.text,
    this.borderRadius = 10.0,
    this.textStyle = const TextStyle(color: Colors.white, fontSize: 12),
    this.showShadow = true,
    this.icon,
    this.iconColor,
  });

  final Color color;
  final String text;
  final double borderRadius;
  final TextStyle textStyle;
  final bool showShadow;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: CompoundDashboardPainter(
          backgroundColor: color,
          borderRadius: borderRadius,
          text: text,
          textStyle: textStyle,
          showShadow: showShadow,
          icon: icon,
          iconColor: iconColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Ultra-wydajny painter dla slot backgrounds - maluje całą siatkę naraz
class PerformantSlotBackgroundPainter extends CustomPainter {
  final double slotWidth;
  final double slotHeight;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final Set<int>? disabledColumns;

  PerformantSlotBackgroundPainter({
    required this.slotWidth,
    required this.slotHeight,
    this.borderColor = const Color(0x1F000000), // Colors.black12
    this.borderWidth = 0.5,
    this.borderRadius = 5.0,
    this.disabledColumns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Oblicz ile slotów mieści się na ekranie
    final slotsHorizontal = (size.width / slotWidth).ceil();
    final slotsVertical = (size.height / slotHeight).ceil();

    // Maluj wszystkie sloty w jednym przejściu
    for (int x = 0; x < slotsHorizontal; x++) {
      // Pomiń disabled columns
      if (disabledColumns?.contains(x) == true) continue;

      for (int y = 0; y < slotsVertical; y++) {
        final rect = Rect.fromLTWH(
          x * slotWidth,
          y * slotHeight,
          slotWidth,
          slotHeight,
        );

        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(borderRadius),
        );

        // Maluj border slot'a bezpośrednio
        canvas.drawRRect(rrect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(PerformantSlotBackgroundPainter oldDelegate) {
    return slotWidth != oldDelegate.slotWidth ||
        slotHeight != oldDelegate.slotHeight ||
        borderColor != oldDelegate.borderColor ||
        borderWidth != oldDelegate.borderWidth ||
        borderRadius != oldDelegate.borderRadius ||
        !_setEquals(disabledColumns, oldDelegate.disabledColumns);
  }

  bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.length == b.length && a.every(b.contains);
  }
}

/// Utility klasa dla wydajnych slot backgrounds
class PerformantSlotBackgroundUtils {
  static const Color defaultBorderColor = Color(0x1F000000);
  static const double defaultBorderWidth = 0.5;

  /// Tworzy overlay z CustomPaint dla wszystkich slotów naraz
  static Widget createSlotBackgroundOverlay({
    required double slotWidth,
    required double slotHeight,
    Color borderColor = defaultBorderColor,
    double borderWidth = defaultBorderWidth,
    Set<int>? disabledColumns,
  }) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: PerformantSlotBackgroundPainter(
          slotWidth: slotWidth,
          slotHeight: slotHeight,
          borderColor: borderColor,
          borderWidth: borderWidth,
          borderRadius: (slotWidth * 0.05).clamp(2.0, 10.0),
          disabledColumns: disabledColumns,
        ),
        size: Size.infinite,
      ),
    );
  }
}
