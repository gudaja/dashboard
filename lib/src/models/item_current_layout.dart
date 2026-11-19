part of '../dashboard_base.dart';

class _ItemCurrentPosition {
  _ItemCurrentPosition(
      {required this.height,
      required this.width,
      required this.y,
      required this.x});

  double width, height, x, y;

  double get endX => x + width;

  double get endY => y + height;

  _ItemCurrentPosition operator +(_ItemCurrentPosition other) {
    return _ItemCurrentPosition(
        height: height + other.height,
        width: width + other.width,
        y: y + other.y,
        x: x + other.x);
  }

  _ItemCurrentPosition operator *(double multiplier) {
    return _ItemCurrentPosition(
        height: height * multiplier,
        width: width * multiplier,
        y: y * multiplier,
        x: x * multiplier);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ItemCurrentPosition &&
        other.width == width &&
        other.height == height &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode => Object.hash(width, height, x, y);

  bool equal(_ItemCurrentPosition other) {
    return x == other.x &&
        y == other.y &&
        width == other.width &&
        height == other.height;
  }

  @override
  String toString() {
    return "ITEM_CURRENT($x, $y , $width , $height)";
  }
}

abstract class _Change {
  _Change(this.direction, this.increment);

  ItemLayout back(ItemLayout layout);

  AxisDirection direction;
  bool increment;
}

class _Resizing extends _Change {
  _Resizing(super.direction, super.increment);

  @override
  String toString() {
    return "RESIZE ${increment ? "increment" : "decrement"} $direction";
  }

  @override
  ItemLayout back(ItemLayout layout) {
    int x = layout.startX,
        y = layout.startY,
        w = layout.width,
        h = layout.height;
    if (direction == AxisDirection.left) {
      x -= 1;
      w += 1;
    } else if (direction == AxisDirection.right) {
      w += 1;
    } else if (direction == AxisDirection.up) {
      y -= 1;
      h += 1;
    } else {
      h += 1;
    }
    return ItemLayout(startX: x, startY: y, width: w, height: h);
  }
}

class _Moving extends _Change {
  _Moving(super.direction, super.increment);

  @override
  String toString() {
    return "MOVE: ${increment ? "increment" : "decrement"} $direction";
  }

  @override
  ItemLayout back(ItemLayout layout) {
    int x = layout.startX, y = layout.startY;
    if (direction == AxisDirection.left) {
      x -= 1;
    } else if (direction == AxisDirection.right) {
      x += 1;
    } else if (direction == AxisDirection.up) {
      y -= 1;
    } else {
      y += 1;
    }
    return ItemLayout(
        startX: x,
        startY: y,
        width: layout.width,
        height: layout.height,
        maxHeight: layout.maxHeight,
        maxWidth: layout.maxWidth,
        minWidth: layout.minWidth,
        minHeight: layout.minHeight);
  }
}

class _Swap extends _Change {
  final ItemLayout origin;

  _Swap({required this.origin}) : super(AxisDirection.down, false);

  @override
  ItemLayout back(ItemLayout layout) {
    return origin;
  }
}

class _Resize {
  _Resize(this.resize, {this.indirectResizes});

  _Resizing resize;

  Map<String, _Change>? indirectResizes;
}

class _ResizeMoveResult {
  _ResizeMoveResult();

  /// Move start offset
  Offset startDifference = const Offset(0, 0);

  bool isChanged = false;
}

///
class _ItemCurrentLayout extends ChangeNotifier implements ItemLayout {
  ///
  _ItemCurrentLayout(this.origin) {
    _transform = ValueNotifier(Offset.zero);
    _resizePosition = ValueNotifier(null);
  }

  late final ValueNotifier<Offset> _transform;

  late final ValueNotifier<_ItemCurrentPosition?> _resizePosition;

  @override
  bool get _haveLocation => origin._haveLocation;

  @override
  set _haveLocation(bool haveLocation) {
    origin._haveLocation = haveLocation;
  }

  /*
      ValueNotifier(ItemCurrentPosition(y: 0, x: 0, height: 0, width: 0))*/

  late GlobalKey<_DashboardItemWidgetState> _key;

  bool _change = false;

  void _clearListeners() {
    _resizePosition.value = null;
    _transform.value = Offset.zero;
    notifyListeners();
  }

  @override
  String toString() {
    return "current: (startX: $startX , startY: $startY , width: $width , height: $height)"
        "\n origin: ($origin)";
  }

  // Cache for position calculation
  _ItemCurrentPosition? _cachedPosition;
  double? _cachedSlotEdge;
  double? _cachedVerticalSlotEdge;
  _ViewportDelegate? _cachedViewportDelegate;

  _ItemCurrentPosition _currentPosition(
      {required _ViewportDelegate viewportDelegate,
      required double slotEdge,
      required double verticalSlotEdge}) {
    // Check if cache is valid
    if (_cachedPosition != null &&
        _cachedSlotEdge == slotEdge &&
        _cachedVerticalSlotEdge == verticalSlotEdge &&
        _cachedViewportDelegate == viewportDelegate) {
      return _cachedPosition!;
    }

    var leftPad = isLeftSide ? 0.0 : viewportDelegate.crossAxisSpace / 2;
    var rightPad = isRightSide ? 0.0 : viewportDelegate.crossAxisSpace / 2;
    var topPad = isTopSide ? 0.0 : viewportDelegate.mainAxisSpace / 2;
    var bottomPad = viewportDelegate.mainAxisSpace / 2;

    // Total width considering virtual columns. Summed per column on purpose:
    // `getColumnPosition(slotCount)` (one past the last column) returns the
    // full constraint width INCLUDING the horizontal padding, so a difference
    // of two positions overshoots the right edge for items in the last column.
    double totalWidth = 0.0;
    for (int i = 0; i < width; i++) {
      totalWidth += _layoutController.getColumnWidth(startX + i);
    }

    _cachedPosition = _ItemCurrentPosition(
        height: height * verticalSlotEdge - topPad - bottomPad,
        width: totalWidth - rightPad - leftPad,
        y: ((startY * (verticalSlotEdge))) +
            viewportDelegate.padding.top +
            topPad,
        x: _layoutController.getColumnPosition(startX) +
            viewportDelegate.padding.left +
            leftPad);

    // Cache the parameters used to calculate this position
    _cachedSlotEdge = slotEdge;
    _cachedVerticalSlotEdge = verticalSlotEdge;
    _cachedViewportDelegate = viewportDelegate;

    return _cachedPosition!;
  }

  // Invalidate cache when position changes
  void _invalidatePositionCache() {
    _cachedPosition = null;
    _cachedSlotEdge = null;
    _cachedVerticalSlotEdge = null;
    _cachedViewportDelegate = null;
  }

  double get _slotEdge {
    return _layoutController.slotEdge;
  }

  double get _verticalSlotEdge {
    return _layoutController.verticalSlotEdge;
  }

  /// Whether the bottom edge stands on the row ceiling ([Dashboard.maxRows]).
  bool get _atCeiling {
    final maxRows = _layoutController.maxRows;
    return maxRows != null && startY + height >= maxRows;
  }

  /// The steps the edge [direction] has to take — growing when [grow], else
  /// shrinking — to reach the next size [Dashboard.isSizeAllowed] accepts,
  /// and how far past its grid line the pointer has to be for the last of
  /// them ([trigger]); `null` when no allowed size is within reach (the grid's
  /// edge, a disabled column, the ceiling, the item's min/max).
  ///
  /// Neighbours are not looked at: pushing them is up to the steps. Without
  /// [Dashboard.isSizeAllowed] this is always one step, at [hysteresis] past
  /// the middle of the next slot, the threshold `_resizeMove` used before
  /// allowed sizes existed.
  ({int steps, double trigger, List<double> slots})? _nextAllowedStep(
      AxisDirection direction, bool grow, double hysteresis) {
    var x = startX, y = startY, w = width, h = height;
    var before = 0.0;
    final slots = <double>[];
    final maxRows = _layoutController.maxRows;
    // Every branch below ends at an edge, a min/max or the ceiling, except
    // growing down an unbounded grid: there the search gives up after this
    // many rows.
    const limit = 256;
    for (var step = 1; step <= limit; step++) {
      double? slot;
      switch ((direction, grow)) {
        case (AxisDirection.left, true):
          if (maxWidth != null && w >= maxWidth!) return null;
          final column = x - 1;
          if (column < 0 || _layoutController.isColumnDisabled(column)) {
            return null;
          }
          slot = _layoutController.getColumnWidth(column);
          x--;
          w++;
        case (AxisDirection.right, true):
          if (maxWidth != null && w >= maxWidth!) return null;
          final column = x + w;
          if (column >= _layoutController.slotCount ||
              _layoutController.isColumnDisabled(column)) {
            return null;
          }
          slot = _layoutController.getColumnWidth(column);
          w++;
        case (AxisDirection.up, true):
          if (y == 0 || (maxHeight != null && h >= maxHeight!)) return null;
          slot = _verticalSlotEdge;
          y--;
          h++;
        case (AxisDirection.down, true):
          if (maxHeight != null && h >= maxHeight!) return null;
          if (maxRows != null && y + h >= maxRows) return null;
          slot = _verticalSlotEdge;
          h++;
        case (AxisDirection.left, false):
          if (w <= minWidth) return null;
          slot = _layoutController.getColumnWidth(x);
          x++;
          w--;
        case (AxisDirection.right, false):
          if (w <= minWidth) return null;
          slot = _layoutController.getColumnWidth(x + w - 1);
          w--;
        case (AxisDirection.up, false):
          if (h <= minHeight) return null;
          slot = _verticalSlotEdge;
          y++;
          h--;
        case (AxisDirection.down, false):
          if (h <= minHeight) return null;
          slot = _verticalSlotEdge;
          h--;
      }
      slots.add(slot);
      if (_layoutController._sizeAllowed(w, h)) {
        return (
          steps: step,
          trigger: before + slot * (0.5 + hysteresis),
          slots: slots
        );
      }
      before += slot;
    }
    return null;
  }

  /// Width of the columns this item may give up before reaching [minWidth].
  double _shrinkableWidth() {
    var total = 0.0;
    for (var i = minWidth; i < width; i++) {
      total += _layoutController.getColumnWidth(startX + i);
    }
    return total;
  }

  /// Resizes by the edges in [holdDirections] while the pointer is at [local].
  ///
  /// [start] is where the current size's edges were under the pointer: every
  /// step taken moves it by the slot it took or gave up, so `local - start` is
  /// always measured from the current grid line. A step is taken when an edge
  /// is past the middle of the next slot (or of its own last slot) by
  /// [hysteresis] of that slot — grow at `0.5 + hysteresis`, and once grown,
  /// shrink back only past `0.5 - hysteresis` of it.
  ///
  /// The item is drawn under the pointer: it may be up to the threshold larger
  /// than its size where it can grow (it can overlap a neighbour until the
  /// step pushes that away), and never smaller than its minimum.
  _ResizeMoveResult _resizeMove({
    required List<AxisDirection> holdDirections,
    required Offset local,
    required Offset start,
    required double scrollDifference,
    required double hysteresis,
    required void Function(String id) onChange,
  }) {
    var difference = local - start;
    difference += Offset(0, scrollDifference);
    if (holdDirections.isEmpty || (difference == Offset.zero)) {
      return _ResizeMoveResult();
    }

    var result = _ResizeMoveResult();
    var drawn = _ItemCurrentPosition(height: 0, width: 0, y: 0, x: 0);

    /// Takes all the steps of [plan] for the edge [direction] — or none: a
    /// step a neighbour blocks takes back the ones before it, so the item
    /// never stops at a size between two allowed ones. Returns how far the
    /// reference point moved.
    Offset steps(AxisDirection direction, bool grow,
        ({int steps, double trigger, List<double> slots}) plan) {
      // Where a step of one slot moves the reference point: outwards for a
      // grown edge, inwards for a shrunk one.
      Offset shift(double slot) {
        final sign = (direction == AxisDirection.left ||
                    direction == AxisDirection.up) ==
                grow
            ? -1.0
            : 1.0;
        return direction == AxisDirection.left ||
                direction == AxisDirection.right
            ? Offset(sign * slot, 0)
            : Offset(0, sign * slot);
      }

      var taken = 0;
      var total = Offset.zero;
      for (final slot in plan.slots) {
        if (tryResize(_Resizing(direction, grow), onChange) == null) break;
        save();
        onChange(id);
        taken++;
        total += shift(slot);
      }
      if (taken == plan.steps) {
        result.startDifference += total;
        result.isChanged = true;
        return total;
      }
      for (var i = 0; i < taken; i++) {
        tryResize(_Resizing(direction, !grow), onChange);
        save();
        onChange(id);
      }
      return Offset.zero;
    }

    ({int steps, double trigger, List<double> slots})? next(
            AxisDirection direction, bool grow) =>
        _nextAllowedStep(direction, grow, hysteresis);

    if (holdDirections.contains(AxisDirection.left)) {
      final grow = next(AxisDirection.left, true);
      final shrink = next(AxisDirection.left, false);
      var dx = difference.dx;
      if (grow != null && dx < -grow.trigger) {
        dx -= steps(AxisDirection.left, true, grow).dx;
      } else if (shrink != null && dx > shrink.trigger) {
        dx -= steps(AxisDirection.left, false, shrink).dx;
      }
      final growNow = next(AxisDirection.left, true);
      dx = dx.clamp(
          growNow == null ? 0.0 : -growNow.trigger, _shrinkableWidth());
      drawn.x += dx;
      drawn.width -= dx;
    }

    if (holdDirections.contains(AxisDirection.up)) {
      final grow = next(AxisDirection.up, true);
      final shrink = next(AxisDirection.up, false);
      var dy = difference.dy;
      if (grow != null && dy < -grow.trigger) {
        dy -= steps(AxisDirection.up, true, grow).dy;
      } else if (shrink != null && dy > shrink.trigger) {
        dy -= steps(AxisDirection.up, false, shrink).dy;
      }
      final growNow = next(AxisDirection.up, true);
      dy = dy.clamp(growNow == null ? 0.0 : -growNow.trigger,
          (height - minHeight) * _verticalSlotEdge);
      drawn.y += dy;
      drawn.height -= dy;
    }

    if (holdDirections.contains(AxisDirection.right)) {
      final grow = next(AxisDirection.right, true);
      final shrink = next(AxisDirection.right, false);
      var dx = difference.dx;
      if (grow != null && dx > grow.trigger) {
        dx -= steps(AxisDirection.right, true, grow).dx;
      } else if (shrink != null && dx < -shrink.trigger) {
        dx -= steps(AxisDirection.right, false, shrink).dx;
      }
      final growNow = next(AxisDirection.right, true);
      dx = dx.clamp(
          -_shrinkableWidth(), growNow == null ? 0.0 : growNow.trigger);
      drawn.width += dx;
    }

    if (holdDirections.contains(AxisDirection.down)) {
      final grow = next(AxisDirection.down, true);
      final shrink = next(AxisDirection.down, false);
      var dy = difference.dy;
      if (grow != null && dy > grow.trigger) {
        dy -= steps(AxisDirection.down, true, grow).dy;
      } else if (shrink != null && dy < -shrink.trigger) {
        dy -= steps(AxisDirection.down, false, shrink).dy;
      }
      final growNow = next(AxisDirection.down, true);
      dy = dy.clamp(-(height - minHeight) * _verticalSlotEdge,
          growNow == null ? 0.0 : growNow.trigger);
      drawn.height += dy;
    }
    _resizePosition.value = drawn;

    return result;
  }

  /// If side is layout bound returns null
  List<_ItemCurrentLayout>? sideItems(AxisDirection direction) {
    var sideItemsIds = <String>[];

    List<int> sideIndexes;

    if (direction == AxisDirection.left) {
      if (startX == 0) {
        return null;
      }
      sideIndexes = _layoutController.getItemIndexes(ItemLayout(
          startX: startX - 1, startY: startY, width: 1, height: height));
    } else if (direction == AxisDirection.right) {
      if ((startX + width) >= _layoutController.slotCount) {
        return null;
      }
      sideIndexes = _layoutController.getItemIndexes(ItemLayout(
          startX: startX + width, startY: startY, width: 1, height: height));
    } else if (direction == AxisDirection.up) {
      if (startY == 0) {
        return null;
      }
      sideIndexes = _layoutController.getItemIndexes(ItemLayout(
          startX: startX, startY: startY - 1, width: width, height: 1));
    } else {
      // The row ceiling bounds the grid like its other edges.
      if (_atCeiling) {
        return null;
      }
      sideIndexes = _layoutController.getItemIndexes(ItemLayout(
          startX: startX, startY: startY + height, width: width, height: 1));
    }

    for (var i in sideIndexes) {
      var item = _layoutController._slotIndex[i];
      if (item != null && !sideItemsIds.contains(item)) {
        sideItemsIds.add(item);
      }
    }

    return sideItemsIds.map((e) => _layoutController._layouts![e]!).toList();
  }

  _Change? tryDecrementOrMoveTo(AxisDirection direction) {
    AxisDirection reverseDir;
    switch (direction) {
      case AxisDirection.up:
        reverseDir = AxisDirection.down;
        break;
      case AxisDirection.right:
        reverseDir = AxisDirection.left;
        break;
      case AxisDirection.down:
        reverseDir = AxisDirection.up;
        break;
      case AxisDirection.left:
        reverseDir = AxisDirection.right;
        break;
    }

    var side = sideItems(direction);

    if (side != null && side.isEmpty) {
      if (direction == AxisDirection.left) {
        // Sprawdź czy nowa pozycja nie jest na zablokowanej kolumnie
        final newLayout = ItemLayout(
            startX: startX - 1, startY: startY, width: width, height: height);
        if (_layoutController.canPlaceAt(newLayout)) {
          _startX = startX - 1;
          return _Moving(reverseDir, false);
        }
        // Nie można przesunąć - spróbuj zmniejszyć zamiast tego
        // (kontynuuj do sekcji resize poniżej)
      } else if (direction == AxisDirection.right) {
        // Sprawdź czy nowa pozycja nie jest na zablokowanej kolumnie
        final newLayout = ItemLayout(
            startX: startX + 1, startY: startY, width: width, height: height);
        if (_layoutController.canPlaceAt(newLayout)) {
          _startX = startX + 1;
          return _Moving(reverseDir, true);
        }
        // Nie można przesunąć - spróbuj zmniejszyć zamiast tego
        // (kontynuuj do sekcji resize poniżej)
      } else if (direction == AxisDirection.up) {
        _startY = startY - 1;
        return _Moving(reverseDir, false);
      } else {
        _startY = startY + 1;
        return _Moving(reverseDir, true);
      }
    }

    // Próba zmniejszenia widgeta (gdy przesunięcie niemożliwe lub są sąsiedzi)
    var resize = _Resizing(reverseDir, false);
    // A pushed neighbour is never shrunk to a size the grid refuses.
    final horizontal =
        reverseDir == AxisDirection.left || reverseDir == AxisDirection.right;
    if (!_layoutController._sizeAllowed(
        horizontal ? width - 1 : width, horizontal ? height : height - 1)) {
      return null;
    }
    if (reverseDir == AxisDirection.up) {
      if (minHeight < height) {
        _height = height - 1;
        _startY = startY + 1;
        return resize;
      }
    } else if (reverseDir == AxisDirection.down) {
      if (minHeight < height) {
        _height = height - 1;
        return resize;
      }
    } else if (reverseDir == AxisDirection.left) {
      if (minWidth < width) {
        _width = width - 1;
        _startX = startX + 1;
        return (resize);
      }
    } else {
      // right
      if (minWidth < width) {
        _width = width - 1;
        return (resize);
      }
    }

    return null;
  }

  void _backResize(_Change change) {
    var res = change.back(ItemLayout(
        startX: startX,
        startY: startY,
        width: width,
        height: height,
        minHeight: minHeight,
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight));

    _startX = res.startX;
    _startY = res.startY;
    _width = res.width;
    _height = res.height;
    // origin = ItemLayout(
    //     startX: startX, startY: startY, width: width, height: height);

    return;
  }

  void _backSwap(_Swap swap) {
    _startX = swap.origin.startX;
    _startY = swap.origin.startY;
    _width = swap.origin.width;
    _height = swap.origin.height;
  }

  _Resize? tryResize(_Resizing? resize, void Function(String id) onChange) {
    if (resize == null) return null;
    var direction = resize.direction;
    if (resize.increment) {
      var lSideItems = sideItems(direction);
      if (lSideItems == null) {
        return null;
      } else if (lSideItems.isEmpty) {
        if (direction == AxisDirection.left) {
          if ((maxWidth == null || width < maxWidth!) &&
              width < _layoutController.slotCount) {
            // Check virtual columns before expanding left
            final newLayout = ItemLayout(
                startX: startX - 1,
                startY: startY,
                width: width + 1,
                height: height);
            if (_layoutController.canPlaceAt(newLayout)) {
              _startX = startX - 1;
              _width = width + 1;
              return _Resize(resize);
            }
          }
        } else if (direction == AxisDirection.right) {
          if ((maxWidth == null || width < maxWidth!) &&
              width < _layoutController.slotCount) {
            // Check virtual columns before expanding right
            final newLayout = ItemLayout(
                startX: startX,
                startY: startY,
                width: width + 1,
                height: height);
            if (_layoutController.canPlaceAt(newLayout)) {
              _width = width + 1;
              return _Resize(resize);
            }
          }
        } else if (direction == AxisDirection.up) {
          if ((maxHeight == null || height < maxHeight!)) {
            _startY = startY - 1;
            _height = height + 1;
            return _Resize(resize);
          }
        } else {
          if (maxHeight == null || height < maxHeight!) {
            _height = height + 1;
            return _Resize(resize);
          }
        }
      } else {
        Map<String, _Change> indirectResizing = {};

        for (var sideItem in lSideItems) {
          var res = sideItem.tryDecrementOrMoveTo(direction);

          if (res == null) {
            indirectResizing.forEach((key, value) {
              _layoutController._layouts![key]?._backResize(value);
              _layoutController._layouts![key]?.save();
            });
            indirectResizing.clear();
            break;
          }
          indirectResizing[sideItem.id] = res;
        }

        if (indirectResizing.isEmpty) return null;

        indirectResizing.forEach((key, value) {
          onChange(key);
          _layoutController._layouts![key]?.save();
        });

        _Resize? result;

        if (direction == AxisDirection.left) {
          if ((maxWidth == null || width < maxWidth!) &&
              width < _layoutController.slotCount) {
            // Check virtual columns before expanding left with indirect resizing
            final newLayout = ItemLayout(
                startX: startX - 1,
                startY: startY,
                width: width + 1,
                height: height);
            if (_layoutController.canPlaceAt(newLayout)) {
              _startX = startX - 1;
              _width = width + 1;
              result = _Resize(resize, indirectResizes: indirectResizing);
            }
          }
        } else if (direction == AxisDirection.right) {
          if ((maxWidth == null || width < maxWidth!) &&
              width < _layoutController.slotCount) {
            // Check virtual columns before expanding right with indirect resizing
            final newLayout = ItemLayout(
                startX: startX,
                startY: startY,
                width: width + 1,
                height: height);
            if (_layoutController.canPlaceAt(newLayout)) {
              _width = width + 1;
              result = _Resize(resize, indirectResizes: indirectResizing);
            }
          }
        } else if (direction == AxisDirection.up) {
          if ((maxHeight == null || height < maxHeight!)) {
            _startY = startY - 1;
            _height = height + 1;
            result = _Resize(resize, indirectResizes: indirectResizing);
          }
        } else {
          if (maxHeight == null || height < maxHeight!) {
            _height = height + 1;
            result = _Resize(resize, indirectResizes: indirectResizing);
          }
        }

        if (result == null) {
          indirectResizing.forEach((key, value) {
            onChange(key);
            _layoutController._layouts![key]?._backResize(value);
            _layoutController._layouts![key]?.save();
          });
          return null;
        } else {
          _layoutController.editSession!._addResize(result, (i, p1) {
            onChange(i);
            _layoutController._layouts![i]?._backResize(p1);
            _layoutController._layouts![i]?.save();
          });

          return result;
        }
      }
    } else {
      _Resize? result;

      //decrement size by direction
      if (direction == AxisDirection.up) {
        if (minHeight < height) {
          _height = height - 1;
          _startY = startY + 1;
          result = _Resize(resize);
        }
      } else if (direction == AxisDirection.down) {
        if (minHeight < height) {
          _height = height - 1;
          result = _Resize(resize);
        }
      } else if (direction == AxisDirection.left) {
        if (minWidth < width) {
          _width = width - 1;
          _startX = startX + 1;
          result = _Resize(resize);
        }
      } else {
        // right
        if (minWidth < width) {
          _width = width - 1;
          result = _Resize(resize);
        }
      }

      if (result != null) {
        _layoutController.editSession!._addResize(result, (id, p1) {
          onChange(id);
          _layoutController._layouts![id]?._backResize(p1);
          _layoutController._layouts![id]?.save();
        });
        return result;
      }
    }
    return null;
  }

  bool _onTransformProcess = false;

  List<int>? _originSize;

  _ResizeMoveResult? _tryTransformFor(
      int newStartX, int newStartY, Offset newTransform) {
    var o = ItemLayout(
        startX: startX, startY: startY, width: width, height: height);

    _layoutController._removeFromIndexes(o, id);

    var i = _layoutController.getIndex([newStartX, newStartY]);

    if (_layoutController._slotIndex.containsKey(i)) {
      _layoutController._indexItem(
          ItemLayout(
              startX: startX,
              startY: startY,
              width: width,
              height: height,
              minHeight: minHeight,
              minWidth: minWidth,
              maxWidth: maxWidth,
              maxHeight: maxHeight),
          id);
      return null;
    }

    var nLayout = _layoutController.tryMount(
        _layoutController.getIndex([newStartX, newStartY]),
        ItemLayout(
            startX: newStartX,
            startY: newStartY,
            width: _originSize![0],
            height: _originSize![1],
            maxHeight: maxHeight,
            maxWidth: maxWidth,
            minWidth: minWidth,
            minHeight: minHeight));

    if (nLayout != null) {
      var c = o.startX != nLayout.startX ||
          o.startY != nLayout.startY ||
          o.width != nLayout.width ||
          o.height != nLayout.height;
      var xDif = nLayout.startX - startX;
      var yDif = nLayout.startY - startY;
      _startX = nLayout.startX;
      _startY = nLayout.startY;
      _width = nLayout.width;
      _height = nLayout.height;
      var dif = Offset(xDif * _slotEdge, yDif * _verticalSlotEdge);

      _transform.value = newTransform - dif;

      save();
      if (!c) {
        _change = false;
      }
      _onTransformProcess = false;

      return _ResizeMoveResult()
        ..isChanged = c
        ..startDifference = dif;
    } else {
      _layoutController._indexItem(
          ItemLayout(
              startX: startX,
              startY: startY,
              width: width,
              height: height,
              minHeight: minHeight,
              minWidth: minWidth,
              maxWidth: maxWidth,
              maxHeight: maxHeight),
          id);
    }
    return null;
  }

  int? _exTrying = -1;
  bool _swapping = false;

  // Śledzenie ostatniej sprawdzonej pozycji grida
  int? _lastCheckedGridX;
  int? _lastCheckedGridY;

  void _removeSwap() {
    if (_swapping) {
      _layoutController.editSession!._swapChanges.forEach((key, value) {
        _layoutController._layouts![key]!._backSwap(value);
      });
      _swapping = false;
    }
  }

  _ResizeMoveResult? _transformUpdate(
      Offset offsetDifference, double scrollDifference, Offset holdOffset) {
    if (_onTransformProcess) return null;

    var newTransform = offsetDifference + Offset(0, scrollDifference);

    // Throttling - ogranicz częstotliwość ciężkich obliczeń do 60 FPS
    // ale zawsze aktualizuj wizualny feedback (_transform)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTransformUpdate != null && now - _lastTransformUpdate! < 16) {
      // Aktualizuj wizualny feedback nawet podczas throttlingu
      _transform.value = newTransform;
      return null;
    }
    _lastTransformUpdate = now;

    _onTransformProcess = true;

    var on = newTransform + holdOffset;

    // Use getColumnFromPosition instead of fixed slotEdge division for proper virtual columns support
    var holdX = _layoutController
        .getColumnFromPosition(
            on.dx + _layoutController.getColumnPosition(origin.startX))
        .clamp(0, _layoutController.slotCount - 1);

    // Jeśli holdX wskazuje na wyłączoną kolumnę, znajdź najbliższą aktywną
    if (_layoutController.isColumnDisabled(holdX)) {
      // Spróbuj znaleźć najbliższą aktywną kolumnę
      final prevEnabled = _layoutController.virtualColumnsConfig
          ?.getPreviousEnabledColumn(holdX);
      final nextEnabled = _layoutController.virtualColumnsConfig
          ?.getNextEnabledColumn(holdX, _layoutController.slotCount);

      if (prevEnabled != null && nextEnabled != null) {
        // Wybierz bliższą
        final currentPos =
            on.dx + _layoutController.getColumnPosition(origin.startX);
        final prevDist =
            (currentPos - _layoutController.getColumnPosition(prevEnabled))
                .abs();
        final nextDist =
            (_layoutController.getColumnPosition(nextEnabled) - currentPos)
                .abs();
        holdX = prevDist < nextDist ? prevEnabled : nextEnabled;
      } else if (prevEnabled != null) {
        holdX = prevEnabled;
      } else if (nextEnabled != null) {
        holdX = nextEnabled;
      }
    }

    var holdY = ((on.dy / _verticalSlotEdge).round() + origin.startY)
        .clamp(0, 4294967296);

    var newStartX = _layoutController
        .getColumnFromPosition(newTransform.dx +
            _layoutController.getColumnPosition(origin.startX))
        .clamp(0, _layoutController.slotCount - 1);
    var newStartY =
        ((newTransform.dy / _verticalSlotEdge).round() + origin.startY)
            .clamp(0, 4294967296);

    // Under a row ceiling a drag past the last row aims at the lowest row the
    // item fits on, so it ends there instead of where it was last placed.
    final maxRows = _layoutController.maxRows;
    if (maxRows != null) {
      newStartY = min(newStartY, max(0, maxRows - _originSize![1]));
    }

    // Jeśli newStartX wskazuje na wyłączoną kolumnę, zostań przy poprzedniej pozycji
    if (_layoutController.isColumnDisabled(newStartX)) {
      // Nie zmieniaj pozycji grida, tylko aktualizuj transform (płynne przeciąganie)
      _transform.value = newTransform;
      _onTransformProcess = false;
      return null;
    }

    // Sprawdź czy pozycja grida się zmieniła
    if (newStartX == _lastCheckedGridX && newStartY == _lastCheckedGridY) {
      // Pozycja grida się nie zmieniła - tylko aktualizuj transform
      _transform.value = newTransform;
      _onTransformProcess = false;
      return null;
    }

    // Aktualizuj ostatnią sprawdzoną pozycję grida
    _lastCheckedGridX = newStartX;
    _lastCheckedGridY = newStartY;

    var haveLeft = newStartX > 0;
    var haveRight = newStartX < _layoutController.slotCount - 1;
    var haveTop = newStartY > 0;

    var slotIndex = _layoutController.getIndex([newStartX, newStartY]);

    final holdItem = _layoutController
        ._slotIndex[_layoutController.getIndex([holdX, holdY])];

    if (holdItem != null && holdItem != id) {
      final holdingItem = _layoutController._layouts![holdItem];

      if (holdingItem != null) {
        var hO = Offset(holdingItem.startX * _slotEdge,
            (holdingItem.startY * _verticalSlotEdge));

        var offsetFromHold =
            Offset(startX * _slotEdge, (startY * _verticalSlotEdge)) + on - hO;

        var holdWH = Offset(holdingItem.width * _slotEdge,
            (holdingItem.height * _verticalSlotEdge));

        if (offsetFromHold.dx > 20 && offsetFromHold.dy > 20) {
          final notRight = offsetFromHold.dx < holdWH.dx - 20;
          final notBottom = offsetFromHold.dy < holdWH.dy - 20;

          if (notRight && notBottom) {
            // TODO: Try swap
          }
        }
      }
    }

    _removeSwap();

    List<int> tryingTo = <int>[];

    if (slotIndex != _exTrying) {
      tryingTo.addAll(<int>[
        /// current
        slotIndex,

        /// bottom
        _layoutController.getIndex([newStartX, newStartY + 1]),

        if (haveTop) ...[
          /// top
          _layoutController.getIndex([newStartX, newStartY - 1]),

          /// top - left
          if (haveLeft)
            _layoutController.getIndex([newStartX - 1, newStartY - 1]),

          /// top - right
          if (haveRight)
            _layoutController.getIndex([newStartX + 1, newStartY - 1]),
        ],

        if (haveLeft) ...[
          /// left
          _layoutController.getIndex([newStartX - 1, newStartY]),

          /// left - bottom
          _layoutController.getIndex([newStartX - 1, newStartY + 1]),
        ],

        if (haveRight) ...[
          /// right
          _layoutController.getIndex([newStartX + 1, newStartY]),

          /// right - bottom
          _layoutController.getIndex([newStartX + 1, newStartY + 1]),
        ],
      ]);
      _exTrying = slotIndex;
    }

    for (var trying in tryingTo) {
      var coordinate = _layoutController.getIndexCoordinate(trying);
      var res = _tryTransformFor(coordinate[0], coordinate[1], newTransform);
      if (res != null) {
        return res;
      }
    }

    _transform.value = newTransform;

    _onTransformProcess = false;
    return null;
  }

  int? _lastTransformUpdate;

  late String id;

  void _mount(_DashboardLayoutController layoutController, String id) {
    // Invalidate position cache when remounting
    _invalidatePositionCache();

    _layoutController = layoutController;
    this.id = id;
    indexes = layoutController.getItemIndexes(origin);
    _endIndex = indexes.last;
    _startIndex = indexes.first;
    _change = true;
  }

  bool get isLeftSide {
    return startX == 0;
  }

  bool get isRightSide {
    return (_endIndex + 1) % (_layoutController.slotCount) == 0;
  }

  bool get isTopSide {
    return startY == 0;
  }

  bool get isBottomSide {
    var last = (_layoutController._endsTree.lastKey())!;
    var lIn = _layoutController.getIndexCoordinate(last);
    return _layoutController.getIndexCoordinate(_endIndex)[1] == lIn[1];
  }

  late int _endIndex;
  late int _startIndex;

  late List<int> indexes;

  late _DashboardLayoutController _layoutController;

  ///
  ItemLayout origin;

  void save() {
    // Invalidate position cache when layout changes
    _invalidatePositionCache();

    // Reset śledzenia pozycji grida gdy element zostanie przeniesiony
    _lastCheckedGridX = null;
    _lastCheckedGridY = null;

    var layout = ItemLayout(
        startX: startX,
        startY: startY,
        width: width,
        height: height,
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        minHeight: minHeight);

    // Zawsze natychmiast aktualizuj indeksy żeby sideItems() działało poprawnie
    // podczas ciągłego resize (nakładanie widgetów)
    _layoutController._reIndexItem(layout, id);
    _change = true;
  }

  int? _height;

  @override
  int get height {
    return _height ?? origin.height;
  }

  @override
  int? get maxHeight {
    return origin.maxHeight;
  }

  @override
  int? get maxWidth {
    return origin.maxWidth;
  }

  @override
  int get minHeight {
    return origin.minHeight;
  }

  @override
  int get minWidth {
    return origin.minWidth;
  }

  int? _startX;

  @override
  int get startX {
    return _startX ?? origin.startX;
  }

  @protected
  set startX(int v) {
    _startX = v;
  }

  int? _startY;

  @override
  int get startY {
    return _startY ?? origin.startY;
  }

  @protected
  set startY(int v) {
    _startY = v;
  }

  int? _width;

  @override
  int get width {
    return _width ?? origin.width;
  }

  _ItemCurrentLayout copy() {
    return _ItemCurrentLayout(origin.copyWithStarts())
      ..indexes = List.from(indexes)
      .._layoutController = _layoutController
      .._endIndex = _endIndex
      .._startIndex = _startIndex
      ..id = id;
  }

  @override
  Map<String, dynamic> toMap() {
    throw UnimplementedError();
  }

  ///
  @override
  ItemLayout copyWithStarts({int? startX, int? startY, int? endX, int? endY}) {
    throw UnimplementedError();
  }

  @override
  ItemLayout copyWithDimension({int? width, int? height}) {
    throw UnimplementedError();
  }

  ItemLayout asLayout() {
    return ItemLayout(
        startX: startX,
        startY: startY,
        width: width,
        height: height,
        minHeight: minHeight,
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight);
  }
}
