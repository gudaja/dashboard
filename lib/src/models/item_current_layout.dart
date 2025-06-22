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

  late Offset offsetDifference;
  late _ItemCurrentPosition positionDifference;

  void adjustResizeOffset(double slotEdge, double verticalSlotEdge,
      _ItemCurrentPosition difPos, _ItemCurrentLayout itemLayout) {
    Offset? difOffset;
    if (resize.increment) {
      if (resize.direction == AxisDirection.left) {
        // Use actual column width for left resize instead of average slotEdge
        final actualSlotWidth =
            itemLayout._layoutController.getColumnWidth(itemLayout.startX - 1);
        difPos
          ..x += actualSlotWidth
          ..width -= actualSlotWidth;
        difOffset = Offset(-actualSlotWidth, 0);
      } else if (resize.direction == AxisDirection.up) {
        difPos
          ..y += verticalSlotEdge
          ..height -= verticalSlotEdge;
        difOffset = Offset(0, -verticalSlotEdge);
      } else if (resize.direction == AxisDirection.right) {
        // Use actual column width for right resize instead of average slotEdge
        final actualSlotWidth = itemLayout._layoutController
            .getColumnWidth(itemLayout.startX + itemLayout.width);
        difPos.width -= actualSlotWidth;
        difOffset = Offset(actualSlotWidth, 0);
      } else {
        difPos.height -= verticalSlotEdge;
        difOffset = Offset(0, verticalSlotEdge);
      }
    } else {
      if (resize.direction == AxisDirection.left) {
        // Use actual column width for left resize instead of average slotEdge
        final actualSlotWidth =
            itemLayout._layoutController.getColumnWidth(itemLayout.startX);
        difPos.x += 0;
        difOffset = Offset(actualSlotWidth, 0);
      } else if (resize.direction == AxisDirection.up) {
        difPos.y += 0;
        difOffset = Offset(0, verticalSlotEdge);
      } else if (resize.direction == AxisDirection.right) {
        // Use actual column width for right resize instead of average slotEdge
        final actualSlotWidth = itemLayout._layoutController
            .getColumnWidth(itemLayout.startX + itemLayout.width - 1);
        difOffset = Offset(-actualSlotWidth, 0);
      } else {
        difOffset = Offset(0, -verticalSlotEdge);
      }
    }

    offsetDifference = difOffset;
    positionDifference = difPos;
  }
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

  _ItemCurrentPosition? _cachedPosition;

  _ItemCurrentPosition _currentPosition(
      {required _ViewportDelegate viewportDelegate,
      required double slotEdge,
      required double verticalSlotEdge}) {
    var leftPad = isLeftSide ? 0.0 : viewportDelegate.crossAxisSpace / 2;
    var rightPad = isRightSide ? 0.0 : viewportDelegate.crossAxisSpace / 2;
    var topPad = isTopSide ? 0.0 : viewportDelegate.mainAxisSpace / 2;
    var bottomPad = viewportDelegate.mainAxisSpace / 2;

    // Calculate total width considering virtual columns
    double totalWidth = 0.0;
    for (int i = 0; i < width; i++) {
      totalWidth += _layoutController.getColumnWidth(startX + i);
    }

    return _ItemCurrentPosition(
        height: height * verticalSlotEdge - topPad - bottomPad,
        width: totalWidth - rightPad - leftPad,
        y: ((startY * (verticalSlotEdge))) +
            viewportDelegate.padding.top +
            topPad,
        x: _layoutController.getColumnPosition(startX) +
            viewportDelegate.padding.left +
            leftPad);
  }

  double get _slotEdge {
    return _layoutController.slotEdge;
  }

  double get _verticalSlotEdge {
    return _layoutController.verticalSlotEdge;
  }

  double _clampDifLeft(double x) {
    // Calculate actual width of widget considering virtual columns
    double actualWidth = 0.0;
    for (int i = startX; i < startX + width; i++) {
      actualWidth += _layoutController.getColumnWidth(i);
    }
    double minActualWidth = 0.0;
    for (int i = startX; i < startX + minWidth; i++) {
      minActualWidth += _layoutController.getColumnWidth(i);
    }
    return x.clamp(0, actualWidth - minActualWidth);
  }

  double _clampDifRight(double x) {
    // Calculate actual width of widget considering virtual columns
    double actualWidth = 0.0;
    for (int i = startX; i < startX + width; i++) {
      actualWidth += _layoutController.getColumnWidth(i);
    }
    double minActualWidth = 0.0;
    for (int i = startX; i < startX + minWidth; i++) {
      minActualWidth += _layoutController.getColumnWidth(i);
    }
    return x.clamp(
      (actualWidth - minActualWidth) * -1,
      0,
    );
  }

  double _clampDifTop(double y) {
    var slot = _verticalSlotEdge;
    return y.clamp(0, (height - minHeight) * slot);
  }

  double _clampDifBottom(double y) {
    var slot = _verticalSlotEdge;
    return y.clamp(
      (height - minHeight) * -slot,
      0,
    );
  }

  _ResizeMoveResult _resizeMove({
    required List<AxisDirection> holdDirections,
    required Offset local,
    required Offset start,
    required double scrollDifference,
    required void Function(String id) onChange,
  }) {
    // Throttling - ogranicz częstotliwość aktualizacji do 60 FPS
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastResizeUpdate != null && now - _lastResizeUpdate! < 16) {
      return _ResizeMoveResult();
    }
    _lastResizeUpdate = now;

    var difference = local - start;
    difference += Offset(0, scrollDifference);
    if (holdDirections.isEmpty || (difference == Offset.zero)) {
      return _ResizeMoveResult();
    }

    var result = _ResizeMoveResult();

    var itemPositionDifference =
        _ItemCurrentPosition(height: 0, width: 0, y: 0, x: 0);

    if (holdDirections.contains(AxisDirection.left)) {
      _Resizing? resizing;

      if (difference.dx < 0) {
        resizing = (_Resizing(AxisDirection.left, true));
      } else if (difference.dx > _layoutController.getColumnWidth(startX)) {
        resizing = (_Resizing(AxisDirection.left, false));
      }

      var res = tryResize(resizing, onChange);
      if (res != null) {
        itemPositionDifference =
            _saveResizeResult(res, itemPositionDifference, result);
        onChange(id);
      } else {
        var dx = _clampDifLeft(difference.dx);
        itemPositionDifference.x += dx;
        itemPositionDifference.width -= dx;
      }
    }
    if (holdDirections.contains(AxisDirection.up)) {
      _Resizing? resizing;

      if (difference.dy < 0) {
        resizing = (_Resizing(AxisDirection.up, true));
      } else if (difference.dy > _verticalSlotEdge) {
        resizing = (_Resizing(AxisDirection.up, false));
      }
      var res = tryResize(resizing, onChange);
      if (res != null) {
        itemPositionDifference =
            _saveResizeResult(res, itemPositionDifference, result);
        onChange(id);
      } else {
        var dy = _clampDifTop(difference.dy);
        itemPositionDifference.y += dy;
        itemPositionDifference.height -= dy;
      }
    }

    if (holdDirections.contains(AxisDirection.right)) {
      _Resizing? resizing;

      if (difference.dx <
          -_layoutController.getColumnWidth(startX + width - 1)) {
        resizing = (_Resizing(AxisDirection.right, false));
      } else if (difference.dx > 0) {
        resizing = (_Resizing(AxisDirection.right, true));
      }
      var res = tryResize(resizing, onChange);
      if (res != null) {
        _saveResizeResult(res, itemPositionDifference, result);
        onChange(id);
      } else {
        var dx = _clampDifRight(difference.dx);
        itemPositionDifference.width += dx;
      }
    }

    if (holdDirections.contains(AxisDirection.down)) {
      _Resizing? resizing;
      //BOTTOM
      if (difference.dy < -_verticalSlotEdge) {
        resizing = (_Resizing(AxisDirection.down, false));
      } else if (difference.dy > 0) {
        resizing = (_Resizing(AxisDirection.down, true));
      }
      var res = tryResize(resizing, onChange);
      if (res != null) {
        _saveResizeResult(res, itemPositionDifference, result);
        onChange(id);
      } else {
        var dy = _clampDifBottom(difference.dy);
        itemPositionDifference.height += dy;
      }
    }
    _resizePosition.value = itemPositionDifference;

    return result;
  }

  _ItemCurrentPosition _saveResizeResult(_Resize res,
      _ItemCurrentPosition itemPositionDifference, _ResizeMoveResult result) {
    save();
    res.adjustResizeOffset(
        _slotEdge, _verticalSlotEdge, itemPositionDifference, this);
    result.startDifference += res.offsetDifference;
    result.isChanged = true;
    return res.positionDifference;
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
      sideIndexes = _layoutController.getItemIndexes(ItemLayout(
          startX: startX, startY: startY + height, width: width, height: 1));
    }

    for (var i in sideIndexes) {
      var item = _layoutController._indexesTree[i];
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
        _startX = startX - 1;
        return _Moving(reverseDir, false);
      } else if (direction == AxisDirection.right) {
        _startX = startX + 1;
        return _Moving(reverseDir, true);
      } else if (direction == AxisDirection.up) {
        _startY = startY - 1;
        return _Moving(reverseDir, false);
      } else {
        _startY = startY + 1;
        return _Moving(reverseDir, true);
      }
    }

    var resize = _Resizing(reverseDir, false);
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

    if (_layoutController._indexesTree.containsKey(i)) {
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

    // Throttling - ogranicz częstotliwość aktualizacji do 60 FPS
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTransformUpdate != null && now - _lastTransformUpdate! < 16) {
      return null;
    }
    _lastTransformUpdate = now;

    _onTransformProcess = true;

    var newTransform = offsetDifference + Offset(0, scrollDifference);

    var on = newTransform + holdOffset;

    // Use getColumnFromPosition instead of fixed slotEdge division for proper virtual columns support
    var holdX = _layoutController
        .getColumnFromPosition(
            on.dx + _layoutController.getColumnPosition(origin.startX))
        .clamp(0, _layoutController.slotCount - 1);

    var holdY = ((on.dy / _verticalSlotEdge).round() + origin.startY)
        .clamp(0, 4294967296);

    var newStartX = _layoutController
        .getColumnFromPosition(newTransform.dx +
            _layoutController.getColumnPosition(origin.startX))
        .clamp(0, _layoutController.slotCount - 1);
    var newStartY =
        ((newTransform.dy / _verticalSlotEdge).round() + origin.startY)
            .clamp(0, 4294967296);

    var haveLeft = newStartX > 0;
    var haveRight = newStartX < _layoutController.slotCount - 1;
    var haveTop = newStartY > 0;

    var slotIndex = _layoutController.getIndex([newStartX, newStartY]);

    final holdItem = _layoutController
        ._indexesTree[_layoutController.getIndex([holdX, holdY])];

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

  int? _lastResizeUpdate;
  int? _lastTransformUpdate;

  late String id;

  void _mount(_DashboardLayoutController layoutController, String id) {
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
    var layout = ItemLayout(
        startX: startX,
        startY: startY,
        width: width,
        height: height,
        minWidth: minWidth,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        minHeight: minHeight);

    // Sprawdź czy to obecnie edytowany element
    final isCurrentlyEditing = _layoutController.editSession?.editing.id == id;

    if (_layoutController.isEditing && !isCurrentlyEditing) {
      // Batch changes dla innych elementów podczas edycji
      _layoutController._batchPendingLayout(id, layout);
    } else {
      // Natychmiastowa aktualizacja dla obecnie edytowanego elementu i poza edycją
      _layoutController._reIndexItem(layout, id);
    }
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
