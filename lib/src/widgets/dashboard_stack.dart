part of '../dashboard_base.dart';

class _DashboardStack<T extends DashboardItem> extends StatefulWidget {
  const _DashboardStack(
      {super.key,
      required this.editModeSettings,
      required this.offset,
      required this.dashboardController,
      required this.itemBuilder,
      required this.cacheExtend,
      required this.maxScrollOffset,
      required this.onScrollStateChange,
      required this.shouldCalculateNewDimensions,
      required this.itemStyle,
      required this.emptyPlaceholder,
      required this.slotBackground});

  final Widget? emptyPlaceholder;
  final ViewportOffset offset;
  final _DashboardLayoutController<T> dashboardController;
  final double cacheExtend;
  final EditModeSettings editModeSettings;
  final SlotBackgroundBuilder<T>? slotBackground;
  final double maxScrollOffset;
  final void Function(bool scrollable) onScrollStateChange;

  ///
  final DashboardItemBuilder<T> itemBuilder;

  final ItemStyle itemStyle;

  final void Function() shouldCalculateNewDimensions;

  @override
  State<_DashboardStack<T>> createState() => _DashboardStackState<T>();
}

class _DashboardStackState<T extends DashboardItem>
    extends State<_DashboardStack<T>> {
  ViewportOffset get viewportOffset => widget.offset;

  _ViewportDelegate get viewportDelegate =>
      widget.dashboardController._viewportDelegate;

  double get pixels => viewportOffset.pixels;

  double get width => viewportDelegate.resolvedConstrains.maxWidth;

  double get height => viewportDelegate.resolvedConstrains.maxHeight;

  @override
  void didUpdateWidget(covariant _DashboardStack<T> old) {
    _widgetsMap.clear();
    super.didUpdateWidget(old);
  }

  ///
  void _listenOffset(ViewportOffset o) {
    setState(() {});
    o.removeListener(_listen);
    o.addListener(_listen);
  }

  ///
  @override
  void didChangeDependencies() {
    _widgetsMap.clear();
    super.didChangeDependencies();
  }

  @override
  void initState() {
    _widgetsMap.clear();
    super.initState();
  }

  @override
  void dispose() {
    viewportOffset.removeListener(_listen);
    super.dispose();
  }

  void _listen() {
    setState(() {});
  }

  Widget buildPositioned(List list) {
    return _DashboardItemWidget<T>(
      style: widget.itemStyle,
      key: _keys[list[2]]!,
      itemGlobalPosition: (list[0] as _ItemCurrentLayout)._currentPosition(
          viewportDelegate: viewportDelegate,
          slotEdge: slotEdge,
          verticalSlotEdge: verticalSlotEdge),
      itemCurrentLayout: list[0],
      id: list[2],
      editModeSettings: widget.editModeSettings,
      child: list[1],
      offset: viewportOffset,
      layoutController: widget.dashboardController,
      item: widget.dashboardController.itemController._items[list[2]]!,
    );
  }

  late double slotEdge;
  late double verticalSlotEdge;
  final Map<String, List> _widgetsMap = <String, List>{};

  void addWidget(String id) {
    var i = widget.dashboardController.itemController._items[id];
    var l = widget.dashboardController._layouts![i!.identifier]!;
    i.layoutData = l.asLayout();

    _widgetsMap[id] = [
      l,
      DashboardItemWidget(
          item: i,
          child: Material(
            elevation: widget.itemStyle.elevation ?? 0.0,
            type: widget.itemStyle.type ?? MaterialType.card,
            shape: widget.itemStyle.shape,
            color: widget.itemStyle.color,
            clipBehavior: widget.itemStyle.clipBehavior ?? Clip.none,
            animationDuration:
                widget.itemStyle.animationDuration ?? kThemeChangeDuration,
            child: widget.itemBuilder(i),
            //shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          )),
      id,
    ];

    _keys[id] ??= GlobalKey<_DashboardItemWidgetState<T>>();
    l._key = _keys[id]!;
  }

  final Map<String, GlobalKey<_DashboardItemWidgetState<T>>> _keys = {};

  late int startIndex, endIndex;

  List<Widget> _buildBackground() {
    final res = <Widget>[];

    int i = startIndex;

    var l =
        viewportDelegate.padding.left + (viewportDelegate.crossAxisSpace / 2);
    var t = viewportDelegate.padding.top -
        pixels +
        (viewportDelegate.mainAxisSpace / 2);
    var h = verticalSlotEdge - viewportDelegate.mainAxisSpace;

    while (i <= endIndex) {
      var x = i % widget.dashboardController.slotCount;
      var y = (i / widget.dashboardController.slotCount).floor();

      // Use virtual columns aware positioning
      var columnPos = widget.dashboardController.getColumnPosition(x);
      var columnWidth = widget.dashboardController.getColumnWidth(x);
      var w = columnWidth - viewportDelegate.crossAxisSpace;

      widget.slotBackground!._itemController =
          widget.dashboardController.itemController;
      res.add(Positioned(
        left: columnPos + l,
        top: y * verticalSlotEdge + t,
        width: w,
        height: h,
        child: Builder(
          builder: (c) {
            return widget.slotBackground!._build(context, x, y);
          },
        ),
      ));
      i++;
    }

    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dashboardController._rebuild) {
      _widgetsMap.clear();
      widget.dashboardController._rebuild = false;
    }

    slotEdge = widget.dashboardController.slotEdge;
    verticalSlotEdge = widget.dashboardController.verticalSlotEdge;
    var startPixels = (viewportOffset.pixels) - widget.cacheExtend;
    var startY = (startPixels / verticalSlotEdge).floor();

    startIndex = widget.dashboardController.getIndex([0, startY]);

    var endPixels = viewportOffset.pixels + height + widget.cacheExtend;
    var endY = (endPixels / verticalSlotEdge).ceil();
    endIndex = widget.dashboardController
        .getIndex([widget.dashboardController.slotCount - 1, endY]);

    var needs = <String>[];
    var key = startIndex;

    if (widget.dashboardController._indexesTree[key] != null) {
      needs.add(widget.dashboardController._indexesTree[key]!);
    }

    while (true) {
      var f = widget.dashboardController._indexesTree.firstKeyAfter(key);
      if (f != null) {
        key = f;
        needs.add(widget.dashboardController._indexesTree[key]!);
        if (key >= endIndex) {
          break;
        }
      } else {
        break;
      }
    }

    var beforeIt = <String>[];
    key = startIndex;
    while (true) {
      var f = widget.dashboardController._indexesTree.lastKeyBefore(key);
      if (f != null) {
        key = f;
        beforeIt.add(widget.dashboardController._indexesTree[key]!);
      } else {
        break;
      }
    }

    var afterIt = <String>[];
    key = startIndex;
    while (true) {
      var f = widget.dashboardController._indexesTree.firstKeyAfter(key);
      if (f != null) {
        key = f;
        afterIt.add(widget.dashboardController._indexesTree[key]!);
      } else {
        break;
      }
    }

    var needDelete = [...afterIt, ...beforeIt];

    var edit = widget.dashboardController.editSession?.editing;

    for (var n in needDelete) {
      if (!needs.contains(n) && n != edit?.id) {
        _widgetsMap.remove(n);
      }
    }

    for (var n in needs) {
      if (!_widgetsMap.containsKey(n)) {
        addWidget(n);
      }
    }

    if (edit != null && !_widgetsMap.containsKey(edit.id)) {
      _widgetsMap.remove(edit.id);
      _keys.remove(edit.id);
      addWidget(edit.id);
    }

    Widget result = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (widget.slotBackground != null) ..._buildBackground(),
        if (widget.dashboardController.isEditing)
          Positioned(
            top: viewportDelegate.padding.top,
            left: viewportDelegate.padding.left,
            width: viewportDelegate.constraints.maxWidth -
                viewportDelegate.padding.vertical,
            height: viewportDelegate.constraints.maxHeight -
                viewportDelegate.padding.horizontal,
            child: Builder(builder: (context) {
              return _AnimatedBackgroundPainter(
                  layoutController: widget.dashboardController,
                  editModeSettings: widget.editModeSettings,
                  offset: viewportOffset);
            }),
          ),
        ..._widgetsMap.entries
            .where((element) =>
                element.value[2] !=
                widget.dashboardController.editSession?.editing.id)
            .map((e) {
          return buildPositioned(e.value);
        }),
        if (widget.dashboardController.itemController._items.isEmpty &&
            !widget.dashboardController._isEditing)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: 0,
              child: widget.emptyPlaceholder ?? Container()),
        ...?(widget.dashboardController.editSession == null
            ? null
            : [
                buildPositioned(_widgetsMap[
                    widget.dashboardController.editSession?.editing.id]!)
              ])
      ],
    );

    if (widget.dashboardController.isEditing) {
      result = GestureDetector(
        onPanStart: widget.editModeSettings.panEnabled
            ? (panStart) {
                _onMoveStart(panStart.localPosition);
              }
            : null,
        onPanUpdate: widget.editModeSettings.panEnabled &&
                edit != null &&
                edit.id.isNotEmpty
            ? (u) {
                setSpeed(u.localPosition);
                _onMoveUpdate(u.localPosition);
              }
            : null,
        onPanEnd: widget.editModeSettings.panEnabled
            ? (e) {
                _onMoveEnd();
              }
            : null,
        onLongPressStart: widget.editModeSettings.longPressEnabled
            ? (longPressStart) {
                _onMoveStart(longPressStart.localPosition);
              }
            : null,
        onLongPressMoveUpdate: widget.editModeSettings.longPressEnabled &&
                edit != null &&
                edit.id.isNotEmpty
            ? (u) {
                setSpeed(u.localPosition);
                _onMoveUpdate(u.localPosition);
              }
            : null,
        onLongPressEnd: widget.editModeSettings.longPressEnabled
            ? (e) {
                _onMoveEnd();
              }
            : null,
        child: result,
      );
    }
    return result;
  }

  void setSpeed(Offset global) {
    if (!widget.editModeSettings.autoScroll) {
      speed = 0;
      return;
    }

    var last = min((height - global.dy), global.dy);
    var m = global.dy < 50 ? -1 : 1;
    if (last < 10) {
      speed = 0.3 * m;
    } else if (last < 20) {
      speed = 0.1 * m;
    } else if (last < 50) {
      speed = 0.05 * m;
    } else {
      speed = 0;
    }
    scroll();
  }

  void scroll() {
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      try {
        if (speed != 0) {
          var n = pixels + speed;

          viewportOffset.jumpTo(n.clamp(0.0, (1 << 31).toDouble()));

          scroll();
        }
      } catch (e) {
        rethrow;
      }
    });
  }

  @override
  void reassemble() {
    _widgetsMap.clear();
    super.reassemble();
  }

  double speed = 0;

  Offset holdOffset = Offset.zero;

  void _onMoveStart(Offset local) {
    // Oblicz pozycję względną (bez padding)
    var holdGlobal = Offset(local.dx - viewportDelegate.padding.left,
        local.dy - viewportDelegate.padding.top);

    var x = widget.dashboardController
        .getColumnFromPositionExact(local.dx - viewportDelegate.padding.left);
    var y =
        (local.dy + pixels - viewportDelegate.padding.top) ~/ verticalSlotEdge;

    var e = widget.dashboardController
        ._indexesTree[widget.dashboardController.getIndex([x, y])];

    if (e is String) {
      var directions = <AxisDirection>[];
      _editing = widget.dashboardController._layouts![e]!;
      var current = _editing!._currentPosition(
          slotEdge: slotEdge,
          viewportDelegate: viewportDelegate,
          verticalSlotEdge: verticalSlotEdge);

      // Popraw obliczenia pozycji elementu - current.x już zawiera padding.left
      var itemGlobal = _ItemCurrentPosition(
          x: current.x - viewportDelegate.padding.left,
          y: current.y - viewportDelegate.padding.top - pixels,
          height: current.height,
          width: current.width);

      if (holdGlobal.dx < itemGlobal.x || holdGlobal.dy < itemGlobal.y) {
        _editing = null;
        setState(() {});
        return;
      }

      // Sprawdź czy kliknięcie jest na przycisku skalowania (bottom-right)
      bool onResizeButton = false;
      if (widget.editModeSettings.resizeHandleBuilder != null) {
        // Przycisk ma 30x30px i jest na pozycji bottom: 5, right: 5
        // Więc zajmuje obszar od (width-35, height-35) do (width-5, height-5)
        double buttonLeft = itemGlobal.endX - 35;
        double buttonTop = itemGlobal.endY - 35;
        double buttonRight = itemGlobal.endX - 5;
        double buttonBottom = itemGlobal.endY - 5;

        onResizeButton = holdGlobal.dx >= buttonLeft &&
            holdGlobal.dx <= buttonRight &&
            holdGlobal.dy >= buttonTop &&
            holdGlobal.dy <= buttonBottom;
      }

      // Lewa krawędź
      if (itemGlobal.x + widget.editModeSettings.resizeCursorSide >
          holdGlobal.dx) {
        directions.add(AxisDirection.left);
      }

      // Górna krawędź
      if ((itemGlobal.y) + widget.editModeSettings.resizeCursorSide >
          holdGlobal.dy) {
        directions.add(AxisDirection.up);
      }

      // Prawa krawędź
      if (itemGlobal.endX - widget.editModeSettings.resizeCursorSide <
              holdGlobal.dx ||
          onResizeButton) {
        directions.add(AxisDirection.right);
      }

      // Dolna krawędź
      if ((itemGlobal.endY) - widget.editModeSettings.resizeCursorSide <
              holdGlobal.dy ||
          onResizeButton) {
        directions.add(AxisDirection.down);
      }
      if (directions.isNotEmpty) {
        _holdDirections = directions;
      } else {
        _holdDirections = null;
      }
      _moveStartOffset = local;
      _startScrollPixels = pixels;
      widget.dashboardController.startEdit(e, _holdDirections == null);

      holdOffset = holdGlobal - Offset(itemGlobal.x, itemGlobal.y);

      var l = widget.dashboardController._layouts![e];
      widget.dashboardController.editSession!.editing._originSize = [
        l!.width,
        l.height
      ];
      setState(() {});
      widget.onScrollStateChange(false);
    } else {
      _moveStartOffset = null;
      _editing = null;
      _holdDirections = null;
      widget.dashboardController.editSession?.editing._originSize = null;
      speed = 0;
      widget.dashboardController.saveEditSession();
      widget.onScrollStateChange(true);
    }
  }

  _ItemCurrentLayout? _editing;

  bool get _editingResize => _holdDirections != null;
  List<AxisDirection>? _holdDirections;
  Offset? _moveStartOffset;
  double? _startScrollPixels;

  bool isResizing(AxisDirection direction) =>
      _holdDirections!.contains(direction);

  int? _lastMoveUpdate;

  void _onMoveUpdate(Offset local) {
    if (_editing == null) {
      return;
    }

    // Throttling - ogranicz częstotliwość aktualizacji do 60 FPS
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastMoveUpdate != null && now - _lastMoveUpdate! < 16) {
      return;
    }
    _lastMoveUpdate = now;

    var e = widget.dashboardController._endsTree.lastKey() ?? 0;

    if (_editingResize) {
      var scrollDifference = pixels - _startScrollPixels!;
      var differences = <String>{};
      var resizeMoveResult = _editing!._resizeMove(
          holdDirections: _holdDirections!,
          local: local,
          onChange: (s) {
            differences.add(s);
          },
          start: _moveStartOffset!,
          scrollDifference: scrollDifference);

      if (resizeMoveResult.isChanged) {
        setState(() {
          _moveStartOffset =
              _moveStartOffset! + resizeMoveResult.startDifference;
          _widgetsMap.remove(_editing!.id);
          for (var r in differences) {
            _widgetsMap.remove(r);
          }
          if (_editing!._endIndex > (e)) {
            widget.shouldCalculateNewDimensions();
          }
        });
      }
    } else {
      var resizeMoveResult = _editing!._transformUpdate(
          local - _moveStartOffset!, pixels - _startScrollPixels!, holdOffset);

      if (resizeMoveResult != null && resizeMoveResult.isChanged) {
        setState(() {
          _moveStartOffset =
              _moveStartOffset! + resizeMoveResult.startDifference;
          _widgetsMap.remove(_editing!.id);

          if (_editing!._endIndex > (e)) {
            widget.shouldCalculateNewDimensions();
          }
        });
      }
    }
  }

  void _onMoveEnd() {
    _lastMoveUpdate = null; // Reset on move end
    _editing?._key = _keys[_editing!.id]!;
    _editing?._key.currentState
        ?._setLast(
            _editing!._transform?.value, _editing!._resizePosition?.value)
        .then((value) {
      widget.dashboardController.editSession?.editing._originSize = null;
      _editing?._clearListeners();
      _editing = null;
      _moveStartOffset = null;
      _holdDirections = null;
      _startScrollPixels = null;
      widget.dashboardController.saveEditSession();
    });
    speed = 0;
    widget.onScrollStateChange(true);
  }
}
