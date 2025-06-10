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

  /// Cache for text widgets to avoid recreating them
  static final Map<String, Widget> _textCache = {};

  /// Cache for container decorations
  static final Map<String, BoxDecoration> _decorationCache = {};

  /// Create optimized text widget with caching
  static Widget createOptimizedText(String text, {TextStyle? style}) {
    final cacheKey = '${text}_${style.hashCode}';
    return _textCache.putIfAbsent(
      cacheKey,
      () => RepaintBoundary(
        child: Text(
          text,
          style: style ??
              const TextStyle(
                fontSize: 12,
                color: Colors.white,
                // Use a common font to avoid font loading jank
                fontFamily: 'sans-serif',
              ),
          textAlign: TextAlign.center,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Create optimized decoration with caching
  static BoxDecoration getOptimizedDecoration({
    required Color color,
    required double borderRadius,
    bool withBorder = false,
  }) {
    final cacheKey = '${color.hashCode}_${borderRadius}_$withBorder';
    return _decorationCache.putIfAbsent(
        cacheKey,
        () => BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              border: withBorder
                  ? Border.all(color: Colors.white70, width: 1)
                  : null,
              // Avoid boxShadow to prevent shader compilation overhead
            ));
  }

  /// Clear caches when needed
  static void clearCaches() {
    _textCache.clear();
    _decorationCache.clear();
  }

  /// Pre-warm common shaders to avoid jank
  static Future<void> preWarmShaders(BuildContext context) async {
    final overlay = Overlay.of(context);

    // Create invisible widgets to pre-compile shaders
    final preWarmWidgets = [
      RepaintBoundary(child: Container(color: Colors.red)),
      RepaintBoundary(
          child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.blue,
        ),
      )),
      const RepaintBoundary(child: Text('Shader Pre-warm')),
    ];

    for (final widget in preWarmWidgets) {
      final entry = OverlayEntry(
        builder: (context) => Positioned(
          left: -100,
          top: -100,
          child: Opacity(opacity: 0.01, child: widget),
        ),
      );

      overlay.insert(entry);
      await Future.delayed(const Duration(milliseconds: 1));
      entry.remove();
    }
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
