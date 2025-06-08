import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:developer' as developer;

/// 📊 Performance Testing Utilities
class PerformanceTester {
  static int _rebuildCount = 0;
  static DateTime? _startTime;
  static List<double> _fpsHistory = [];

  /// Resetuje countery
  static void reset() {
    _rebuildCount = 0;
    _startTime = DateTime.now();
    _fpsHistory.clear();
    if (kDebugMode) {
      debugPrint('🔄 Performance monitoring started');
    }
  }

  /// Liczy rebuildy
  static void trackRebuild(String widgetName) {
    _rebuildCount++;
    if (kDebugMode) {
      debugPrint('🔨 Rebuild #$_rebuildCount: $widgetName');
    }
  }

  /// Pokazuje statystyki
  static void showStats() {
    final elapsed = DateTime.now().difference(_startTime ?? DateTime.now());
    debugPrint('''
📈 PERFORMANCE STATS:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏱️  Elapsed time: ${elapsed.inSeconds}s
🔨 Total rebuilds: $_rebuildCount
🎯 Rebuilds/sec: ${elapsed.inSeconds > 0 ? (_rebuildCount / elapsed.inSeconds).toStringAsFixed(2) : '0'}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ''');
  }

  /// Track FPS (call in animation frame)
  static void trackFPS(double fps) {
    _fpsHistory.add(fps);
    if (_fpsHistory.length > 60) {
      // Keep last 60 frames
      _fpsHistory.removeAt(0);
    }
  }
}

/// 🎭 Widget do trackowania rebuilds
class RebuildTracker extends StatelessWidget {
  const RebuildTracker({
    super.key,
    required this.name,
    required this.child,
  });

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    PerformanceTester.trackRebuild(name);
    return child;
  }
}

/// 📱 Simplified Performance Monitor
class PerformanceMonitor extends StatefulWidget {
  const PerformanceMonitor({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  @override
  void initState() {
    super.initState();
    PerformanceTester.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (kDebugMode)
          Positioned(
            top: 100,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📊 Performance',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                  ElevatedButton(
                    onPressed: PerformanceTester.showStats,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 30),
                    ),
                    child: const Text('Stats', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 🧪 Memory Usage Monitor
class MemoryMonitor {
  static void trackMemory(String label) {
    if (kDebugMode) {
      developer.Timeline.instantSync('Memory: $label');
    }
  }

  static void startMemoryProfiling() {
    if (kDebugMode) {
      developer.Timeline.startSync('Memory Profile');
    }
  }

  static void endMemoryProfiling() {
    if (kDebugMode) {
      developer.Timeline.finishSync();
    }
  }
}

/// 🎯 Benchmark Widget
class BenchmarkWidget extends StatefulWidget {
  const BenchmarkWidget({
    super.key,
    required this.testName,
    required this.child,
  });

  final String testName;
  final Widget child;

  @override
  State<BenchmarkWidget> createState() => _BenchmarkWidgetState();
}

class _BenchmarkWidgetState extends State<BenchmarkWidget> {
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    MemoryMonitor.trackMemory('${widget.testName} - Start');
  }

  @override
  void dispose() {
    final elapsed = DateTime.now().difference(_startTime);
    if (kDebugMode) {
      debugPrint(
          '⏱️ ${widget.testName} lived for: ${elapsed.inMilliseconds}ms');
    }
    MemoryMonitor.trackMemory('${widget.testName} - End');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RebuildTracker(
      name: widget.testName,
      child: widget.child,
    );
  }
}
