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

/// It contains current positions and offsets.
class _ItemCurrentLayout extends ItemLayout {
  ///
  _ItemCurrentLayout(super.layout) : super.fromLayout();

  final ValueNotifier<Offset> _transformNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<Offset> _resizeNotifier = ValueNotifier(Offset.zero);

  _ItemCurrentPosition? _cachedPosition;

  GlobalKey<_DashboardItemWidgetState> _key =
      GlobalKey<_DashboardItemWidgetState>();

  _DashboardLayoutController? _layoutController;

  String? id;

  void _mount(
      _DashboardLayoutController layoutController, String id, GlobalKey key) {
    _layoutController = layoutController;
    this.id = id;
    _key = key;
  }

  void _unmount() {
    _layoutController = null;
    id = null;
  }

  int get _endIndex {
    return _layoutController!.getIndex([startX + width - 1, startY + height]);
  }

  int get _startIndex {
    return _layoutController!.getIndex([startX, startY]);
  }

  ///
  @override
  String toString() {
    return "id: $id start: ($_startIndex, $startX, $startY), end: ($_endIndex, ${startX + width}, ${startY + height}) size: ($width, $height)"
        "\n origin: ($origin)";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ItemCurrentLayout &&
        other.width == width &&
        other.height == height &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode => Object.hash(width, height, x, y);

  Rect getFillPosition(
      {required double slotEdge,
      required double verticalSlotEdge,
      required _ViewportDelegate viewportDelegate}) {
    var cp = _currentPosition(
        viewportDelegate: viewportDelegate,
        slotEdge: slotEdge,
        verticalSlotEdge: verticalSlotEdge);

    return Rect.fromLTWH(cp.x - viewportDelegate.padding.left,
        cp.y - viewportDelegate.padding.top, cp.width, cp.height);
  }

  _ItemCurrentPosition _currentPosition(
      {required _ViewportDelegate viewportDelegate,
      required double slotEdge,
      required double verticalSlotEdge}) {
    var leftPad = viewportDelegate.padding.left;
    var rightPad = viewportDelegate.padding.right;

    var topPad = viewportDelegate.padding.top;
    var bottomPad = viewportDelegate.padding.bottom;

    double totalWidth = 0;

    for (int i = 0; i < width; i++) {
      totalWidth += _layoutController!.getColumnWidth(startX + i);
    }

    var newPosition = _ItemCurrentPosition(
        height: height * verticalSlotEdge - topPad - bottomPad,
        width: totalWidth - rightPad - leftPad,
        y: ((startY * (verticalSlotEdge))) +
            viewportDelegate.padding.top +
            topPad,
        x: _layoutController!.getColumnPosition(startX) +
            viewportDelegate.padding.left +
            leftPad);

    if (_cachedPosition != null && _cachedPosition == newPosition) {
      return _cachedPosition!;
    } else {
      return _cachedPosition = newPosition;
    }
  }

  double get _slotEdge {
    return _layoutController!.slotEdge;
  }

  double get _verticalSlotEdge {
    return _layoutController!.verticalSlotEdge;
  }
}
