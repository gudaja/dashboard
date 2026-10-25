// Measures the slot index of the layout controller (slot index → item id):
// the SplayTreeMap `_indexesTree` the fork used up to 0.0.13 against the
// HashMap-based `FastIndexMap` from the upstream `local` branch
// (Mehmetyaz/dashboard f37e788). The fork switched to C (`_SlotIndex`) after
// this measurement. Pure Dart, no Flutter:
//
//   dart run tool/bench_index_map.dart                 # JIT
//   dart compile exe tool/bench_index_map.dart -o build/bench && build/bench  # AOT, as in release
//
// A's loops are copied from `_DashboardStackState.build` as of 0.0.13.
// ignore_for_file: avoid_print
import 'dart:collection';
import 'dart:math';

/// Upstream's FastIndexMap, verbatim apart from the class name.
class FastIndexMap {
  final Map<int, String> _map = <int, String>{};
  String? operator [](int index) => _map[index];
  void operator []=(int index, String value) => _map[index] = value;
  bool containsKey(int index) => _map.containsKey(index);
  String? remove(int index) => _map.remove(index);
  Set<String> itemsInRange(int startIndex, int endIndex) {
    final result = <String>{};
    final start = startIndex < 0 ? 0 : startIndex;
    for (var i = start; i <= endIndex; i++) {
      final id = _map[i];
      if (id != null) result.add(id);
    }
    return result;
  }
}

class Scenario {
  const Scenario(this.name, this.slotCount, this.items, this.visibleRows);
  final String name;
  final int slotCount;
  final int items;

  /// Rows built per frame: the viewport plus `cacheExtend` on both sides.
  final int visibleRows;
}

const scenarios = [
  Scenario('kokpit: 14 kolumn, 30 kafelków', 14, 30, 10),
  Scenario('średnia: 20 kolumn, 150 kafelków', 20, 150, 12),
  Scenario('duża: 24 kolumny, 600 kafelków', 24, 600, 14),
];

/// Item id → occupied slot indexes, packed row by row with sizes 1..3.
Map<String, List<int>> layout(Scenario s) {
  final rnd = Random(7);
  final taken = <int>{};
  final result = <String, List<int>>{};
  var y = 0, x = 0;
  for (var n = 0; n < s.items; n++) {
    final w = 1 + rnd.nextInt(3), h = 1 + rnd.nextInt(3);
    while (true) {
      if (x + w > s.slotCount) {
        x = 0;
        y++;
        continue;
      }
      final cells = [
        for (var dy = 0; dy < h; dy++)
          for (var dx = 0; dx < w; dx++) (y + dy) * s.slotCount + x + dx
      ];
      if (cells.any(taken.contains)) {
        x++;
        continue;
      }
      taken.addAll(cells);
      result['i$n'] = cells;
      x += w;
      break;
    }
  }
  return result;
}

/// The fork up to 0.0.13: walk from startIndex to endIndex, then walk the WHOLE tree
/// before and after startIndex to find what to drop.
int queryFork(SplayTreeMap<int, String> tree, int startIndex, int endIndex) {
  var needs = <String>[];
  var key = startIndex;
  if (tree[key] != null) needs.add(tree[key]!);
  while (true) {
    var f = tree.firstKeyAfter(key);
    if (f != null) {
      key = f;
      needs.add(tree[key]!);
      if (key >= endIndex) break;
    } else {
      break;
    }
  }
  var beforeIt = <String>[];
  key = startIndex;
  while (true) {
    var f = tree.lastKeyBefore(key);
    if (f != null) {
      key = f;
      beforeIt.add(tree[key]!);
    } else {
      break;
    }
  }
  var afterIt = <String>[];
  key = startIndex;
  while (true) {
    var f = tree.firstKeyAfter(key);
    if (f != null) {
      key = f;
      afterIt.add(tree[key]!);
    } else {
      break;
    }
  }
  var needDelete = [...afterIt, ...beforeIt];
  return needs.length + needDelete.length;
}

/// Same tree, only the visible range walked; what to drop comes from the
/// widget map (`removeWhere`), as upstream does it.
int queryTreeRange(SplayTreeMap<int, String> tree, int startIndex, int endIndex,
    Map<String, Object> widgets) {
  final needs = <String>{};
  var key = tree.containsKey(startIndex)
      ? startIndex
      : tree.firstKeyAfter(startIndex);
  while (key != null && key <= endIndex) {
    needs.add(tree[key]!);
    key = tree.firstKeyAfter(key);
  }
  widgets.removeWhere((id, _) => !needs.contains(id));
  return needs.length;
}

/// Upstream: scan every slot of the visible range in the hash map.
int queryHash(FastIndexMap map, int startIndex, int endIndex,
    Map<String, Object> widgets) {
  final needs = map.itemsInRange(startIndex, endIndex);
  widgets.removeWhere((id, _) => !needs.contains(id));
  return needs.length;
}

/// Microseconds per call, best of 5 runs of [iterations] after a warm-up.
double time(int iterations, int Function() body) {
  var sink = 0;
  for (var i = 0; i < iterations; i++) {
    sink += body();
  }
  var best = double.infinity;
  for (var run = 0; run < 5; run++) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      sink += body();
    }
    best = min(best, sw.elapsedMicroseconds / iterations);
  }
  if (sink == 42) print('');
  return best;
}

String fmt(double us) =>
    us < 10 ? '${us.toStringAsFixed(2)} µs' : '${us.toStringAsFixed(1)} µs';

void main() {
  for (final s in scenarios) {
    final items = layout(s);
    final tree = SplayTreeMap<int, String>();
    final hash = FastIndexMap();
    items.forEach((id, cells) {
      for (final c in cells) {
        tree[c] = id;
        hash[c] = id;
      }
    });
    final rows = tree.lastKey()! ~/ s.slotCount + 1;
    // Scrolled to the middle of the grid.
    final startRow = max(0, rows ~/ 2 - s.visibleRows ~/ 2);
    final startIndex = startRow * s.slotCount;
    final endIndex = (startRow + s.visibleRows) * s.slotCount - 1;
    final widgets = {for (final id in items.keys) id: Object()};
    Map<String, Object> freshWidgets() => Map.of(widgets);

    print('\n## ${s.name} — ${tree.length} zajętych slotów, $rows wierszy, '
        'w widoku ${s.visibleRows} wierszy');

    // All three must find the same items, or the timings compare nothing.
    final inRange = {
      for (final e in tree.entries)
        if (e.key >= startIndex && e.key <= endIndex) e.value
    };
    final viaTree = Map.of(widgets);
    queryTreeRange(tree, startIndex, endIndex, viaTree);
    final viaHash = Map.of(widgets);
    queryHash(hash, startIndex, endIndex, viaHash);
    final forkNeeds = <String>{};
    var k = tree.containsKey(startIndex) ? startIndex : null;
    if (k != null) forkNeeds.add(tree[k]!);
    k = startIndex;
    while (true) {
      final f = tree.firstKeyAfter(k!);
      if (f == null) break;
      k = f;
      forkNeeds.add(tree[k]!);
      if (k >= endIndex) break;
    }
    print(
        'zgodność: B=${viaTree.keys.toSet().containsAll(inRange) && inRange.containsAll(viaTree.keys)} '
        'C=${viaHash.keys.toSet().containsAll(inRange) && inRange.containsAll(viaHash.keys)} '
        'A⊇widoczne=${forkNeeds.containsAll(inRange)} '
        '(A ma o ${forkNeeds.length - inRange.length} więcej)');

    // 1. Visible-items query, once per stack build.
    const q = 20000;
    final a = time(q, () => queryFork(tree, startIndex, endIndex));
    final b = time(
        q, () => queryTreeRange(tree, startIndex, endIndex, freshWidgets()));
    final c =
        time(q, () => queryHash(hash, startIndex, endIndex, freshWidgets()));
    final copy = time(q, () => freshWidgets().length);
    print('zapytanie o widoczne (na budowę stosu):');
    print('  A fork do 0.0.13 (SplayTree, obchód)  ${fmt(a)}');
    print('  B SplayTree, tylko widoczny zakres   ${fmt(b - copy)}');
    print('  C upstream (HashMap, itemsInRange)   ${fmt(c - copy)}');

    // 2. Point lookups: the slot background asks for every visible slot.
    final visibleSlots = [for (var i = startIndex; i <= endIndex; i++) i];
    final tl = time(2000, () {
      var n = 0;
      for (final i in visibleSlots) {
        if (tree[i] != null) n++;
      }
      return n;
    });
    final hl = time(2000, () {
      var n = 0;
      for (final i in visibleSlots) {
        if (hash[i] != null) n++;
      }
      return n;
    });
    print('odczyt ${visibleSlots.length} widocznych slotów (tło siatki):');
    print('  SplayTreeMap ${fmt(tl)}   HashMap ${fmt(hl)}');

    // 3. Mount/unmount of one 2x2 item in the middle (tryMount + index).
    final probe = [
      startIndex + 1,
      startIndex + 2,
      startIndex + 1 + s.slotCount,
      startIndex + 2 + s.slotCount
    ];
    final saved = {for (final p in probe) p: tree[p]};
    int remount(void Function(int, String) put, String? Function(int) remove,
        bool Function(int) has) {
      for (final p in probe) {
        remove(p);
      }
      var free = 0;
      for (final p in probe) {
        if (!has(p)) free++;
      }
      for (final p in probe) {
        put(p, 'probe');
      }
      return free;
    }

    final tm = time(20000,
        () => remount((k, v) => tree[k] = v, tree.remove, tree.containsKey));
    final hm = time(20000,
        () => remount((k, v) => hash[k] = v, hash.remove, hash.containsKey));
    saved.forEach((k, v) {
      if (v != null) {
        tree[k] = v;
        hash[k] = v;
      }
    });
    print('przemontowanie kafelka 2x2 (usuń, sprawdź, wstaw):');
    print('  SplayTreeMap ${fmt(tm)}   HashMap ${fmt(hm)}');
  }
}
