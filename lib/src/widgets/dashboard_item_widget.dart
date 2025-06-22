part of '../dashboard_base.dart';

class DashboardItemWidget<T extends DashboardItem> extends InheritedWidget {
  const DashboardItemWidget(
      {required this.item, required super.child, super.key});

  final DashboardItem item;

  static DashboardItemWidget<T> of<T extends DashboardItem>(
      BuildContext context) {
    final DashboardItemWidget? result =
        context.dependOnInheritedWidgetOfExactType<DashboardItemWidget>();
    assert(result != null, 'No DashboardItemWidget found in context');
    return result! as DashboardItemWidget<T>;
  }

  @override
  bool updateShouldNotify(covariant DashboardItemWidget oldWidget) {
    return oldWidget.item.identifier != item.identifier;
  }
}

class _DashboardItemWidget<T extends DashboardItem> extends StatefulWidget {
  const _DashboardItemWidget(
      {required Key key,
      required this.layoutController,
      required this.child,
      required this.editModeSettings,
      required this.id,
      required this.itemCurrentLayout,
      required this.itemGlobalPosition,
      required this.offset,
      required this.style,
      required this.item})
      : super(key: key);

  final _ItemCurrentLayout itemCurrentLayout;
  final Widget child;
  final String id;
  final _DashboardLayoutController layoutController;
  final EditModeSettings editModeSettings;
  final _ItemCurrentPosition itemGlobalPosition;
  final ViewportOffset offset;
  final ItemStyle style;
  final T item;

  @override
  State<_DashboardItemWidget<T>> createState() =>
      _DashboardItemWidgetState<T>();
}

class _DashboardItemWidgetState<T extends DashboardItem>
    extends State<_DashboardItemWidget<T>> with TickerProviderStateMixin {
  late MouseCursor cursor;

  // late double leftPad, rightPad, topPad, bottomPad;

  @override
  void dispose() {
    _animationController.dispose();
    _multiplierAnimationController.dispose();
    widget.itemCurrentLayout.removeListener(_listen);
    super.dispose();
  }

  void _listen() {
    setState(() {});
  }

  late AnimationController _multiplierAnimationController;

  @override
  void initState() {
    cursor = MouseCursor.defer;
    _animationController = AnimationController(
        vsync: this, duration: widget.editModeSettings.duration);
    _multiplierAnimationController = AnimationController(
        vsync: this, value: 0, duration: widget.editModeSettings.duration);
    widget.itemCurrentLayout.addListener(_listen);
    super.initState();
  }

  _ItemCurrentPosition? get _resizePosition =>
      widget.itemCurrentLayout._resizePosition?.value;

  bool onRightSide(double dX) =>
      dX >
      (widget.itemGlobalPosition.width + (_resizePosition?.width ?? 0)) -
          widget.editModeSettings.resizeCursorSide;

  bool onLeftSide(double dX) =>
      (dX + (_resizePosition?.x ?? 0)) <
      widget.editModeSettings.resizeCursorSide;

  bool onTopSide(double dY) =>
      (dY + (_resizePosition?.y ?? 0)) <
      widget.editModeSettings.resizeCursorSide;

  bool onBottomSide(double dY) =>
      dY >
      (widget.itemGlobalPosition.height + (_resizePosition?.height ?? 0)) -
          widget.editModeSettings.resizeCursorSide;

  // Sprawdza czy pozycja jest na przycisku skalowania (bottom-right)
  bool onResizeHandle(double dX, double dY) {
    if (widget.editModeSettings.resizeHandleBuilder == null) return false;

    final widgetWidth =
        widget.itemGlobalPosition.width + (_resizePosition?.width ?? 0);
    final widgetHeight =
        widget.itemGlobalPosition.height + (_resizePosition?.height ?? 0);

    // Przycisk ma 30x30px i jest na pozycji bottom: 5, right: 5
    // Więc zajmuje obszar od (width-35, height-35) do (width-5, height-5)
    return dX >= widgetWidth - 35 &&
        dX <= widgetWidth - 5 &&
        dY >= widgetHeight - 35 &&
        dY <= widgetHeight - 5;
  }

  void _hover(PointerHoverEvent hover) {
    var x = hover.localPosition.dx;
    var y = hover.localPosition.dy;
    MouseCursor cursor;

    // Sprawdź najpierw czy jesteśmy na przycisku skalowania
    var onResizeButton = onResizeHandle(x, y);
    var r = onRightSide(x) || onResizeButton;
    var l = onLeftSide(x);
    var t = onTopSide(y);
    var b = onBottomSide(y) || onResizeButton;

    if (r) {
      if (b) {
        cursor = SystemMouseCursors.resizeUpLeftDownRight;
      } else if (t) {
        cursor = SystemMouseCursors.resizeUpRightDownLeft;
      } else {
        cursor = SystemMouseCursors.resizeLeftRight;
      }
    } else if (l) {
      if (b) {
        cursor = SystemMouseCursors.resizeUpRightDownLeft;
      } else if (t) {
        cursor = SystemMouseCursors.resizeUpLeftDownRight;
      } else {
        cursor = SystemMouseCursors.resizeLeftRight;
      }
    } else if (b || t) {
      cursor = SystemMouseCursors.resizeUpDown;
    } else {
      cursor = SystemMouseCursors.move;
    }
    if (this.cursor != cursor) {
      setState(() {
        this.cursor = cursor;
      });
    }
  }

  void _exit(PointerExitEvent exit) {
    setState(() {
      cursor = MouseCursor.defer;
    });
  }

  Offset transform = Offset.zero;

  Offset? panStart;

  double scrollOffset = 0;

  double startScrollOffset = 0;

  _ItemCurrentLayout get l => widget.itemCurrentLayout;

  double get slotEdge => widget.layoutController.slotEdge;

  _ItemCurrentPosition? ex;

  late AnimationController _animationController;
  Animation<_ItemCurrentPosition>? _animation;

  Offset? _lastTransform;
  _ItemCurrentPosition? _lastPosition;

  Future<void> _setLast(
      Offset? lastOffset, _ItemCurrentPosition? lastPosition) async {
    _lastTransform = lastOffset;
    _lastPosition = lastPosition;
    _multiplierAnimationController.reset();
    _multiplierAnimationController.value = 1;
    await _multiplierAnimationController
        .animateTo(0,
            duration: widget.editModeSettings.duration,
            curve: widget.editModeSettings.curve)
        .then((value) {
      setState(() {
        _lastTransform = null;
        _lastPosition = null;
      });
    });
  }

  bool get onEditMode => widget.layoutController.isEditing;

  ItemLayout? _exLayout;

  bool equal() {
    return _exLayout!.startX == widget.itemCurrentLayout.startX &&
        _exLayout!.startY == widget.itemCurrentLayout.startY &&
        _exLayout!.width == widget.itemCurrentLayout.width &&
        _exLayout!.height == widget.itemCurrentLayout.height;
  }

  bool onAnimation = false;
  DateTime? animationStart;

  Offset? _dragOffset;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragOffset = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset ?? Offset.zero) + details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragOffset = null;
    });
    // Możesz tu powiadomić kontroler o zakończeniu przeciągania
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.itemGlobalPosition;
    final offset = _dragOffset ?? Offset.zero;

    return Positioned(
      left: pos.x + offset.dx,
      top: pos.y + offset.dy,
      width: pos.width,
      height: pos.height,
      child: RepaintBoundary(
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: DashboardItemWidget(
            item: widget.item,
            child: Material(
              elevation: widget.style.elevation ?? 0.0,
              type: widget.style.type ?? MaterialType.card,
              shape: widget.style.shape,
              color: widget.style.color,
              clipBehavior: widget.style.clipBehavior ?? Clip.none,
              animationDuration:
                  widget.style.animationDuration ?? kThemeChangeDuration,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
