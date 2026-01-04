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
    final key = '${color.value}_$borderRadius';
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
