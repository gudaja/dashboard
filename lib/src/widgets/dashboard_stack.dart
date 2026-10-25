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
    extends State<_DashboardStack<T>> with SingleTickerProviderStateMixin {
  ViewportOffset get viewportOffset => widget.offset;

  _ViewportDelegate get viewportDelegate =>
      widget.dashboardController._viewportDelegate;

  double get pixels => viewportOffset.pixels;

  double get width => viewportDelegate.resolvedConstrains.maxWidth;

  double get height => viewportDelegate.resolvedConstrains.maxHeight;

  @override
  void didUpdateWidget(covariant _DashboardStack<T> old) {
    // Being rebuilt does NOT make the cached item widgets stale — only a changed
    // PARAMETER does. `Dashboard` recreates this stack from its own `setState`
    // (it listens to the layout controller, `dashboard.dart:241`, `:252`) with
    // every field identical, and clearing here cost a second `itemBuilder` call
    // for every item on screen: measured at mount on a phone frame as 48 calls
    // for 24 items, because `_listenOffset` schedules exactly one such rebuild.
    if (_parametersChangedFrom(old)) {
      _clearWidgets();
    }
    super.didUpdateWidget(old);
  }

  /// Whether [old] carries anything this stack BAKES INTO a cached widget.
  ///
  /// `_widgetsMap` holds `itemBuilder`'s output wrapped in a `Material` built
  /// from [ItemStyle], and the static layer bakes the edit-mode settings, the
  /// viewport offset and the controller into every item. Everything else the
  /// widget carries — `cacheExtend`, `maxScrollOffset`, the callbacks, the empty
  /// placeholder — is read fresh on every build and cannot make a cached child
  /// stale.
  bool _parametersChangedFrom(_DashboardStack<T> old) =>
      !identical(old.itemBuilder, widget.itemBuilder) ||
      !identical(old.itemStyle, widget.itemStyle) ||
      !identical(old.offset, widget.offset) ||
      !identical(old.dashboardController, widget.dashboardController) ||
      !identical(old.slotBackground, widget.slotBackground) ||
      !identical(old.editModeSettings, widget.editModeSettings);

  ///
  void _listenOffset(ViewportOffset o) {
    setState(() {});
    o.removeListener(_listen);
    o.addListener(_listen);
  }

  ///
  @override
  void didChangeDependencies() {
    _clearWidgets();
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _clearWidgets();
    // The slot geometry is already known when this stack is first built:
    // `Dashboard._setNewOffset` attaches the layout controller and calls
    // `_setSizes` (`dashboard.dart:341`, `:357`, `:384`) before the viewport
    // builder constructs us (`:566`). Starting from the real numbers instead of
    // 0.0 means the first pass computes the right band straight away.
    //
    // `slotEdge`/`verticalSlotEdge` are `late` fields
    // (`dashboard_controller.dart:306`), so they may only be read once the
    // controller has been attached — and every path that sets `_isAttached` runs
    // `_setSizes` in the same pass, which is what makes this check sufficient.
    if (widget.dashboardController._isAttached) {
      slotEdge = widget.dashboardController.slotEdge;
      verticalSlotEdge = widget.dashboardController.verticalSlotEdge;
    }
  }

  @override
  void dispose() {
    viewportOffset.removeListener(_listen);
    _autoScrollTicker?.dispose();
    _listenedCarousel?.removeListener(_onCarouselMoved);
    if (_editing != null) {
      // Disposed under a dragging pointer. The listeners of these notifiers
      // may rebuild, which a tree being torn down does not allow.
      final itemController = widget.dashboardController.itemController;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        itemController._dragPointer.value = null;
        itemController._liftedItem.value = null;
      });
    }
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

  double slotEdge = 0.0;
  double verticalSlotEdge = 0.0;
  final Map<String, List> _widgetsMap = <String, List>{};

  /// Revision of the KEY SET the static layer renders.
  ///
  /// The static cache ([_cachedStaticWidgets]) is a list built from the keys of
  /// [_widgetsMap] at one moment in time, so it is valid for THAT set of keys and
  /// for no other. This counter is the cheap way to say „the set moved": every
  /// mutation of the map goes through [_clearWidgets], [_removeWidget] or
  /// [addWidget], and each of them bumps it.
  int _widgetsRevision = 0;

  /// Marks the key set of [_widgetsMap] as changed.
  ///
  /// The item being EDITED is deliberately exempt. The static layer never
  /// renders it — `_buildStaticWidgets` filters it out and `_buildEditingOverlay`
  /// draws it on top — while a drag takes it out of the map and puts it back on
  /// every single frame (`_onMoveUpdate`, and the `edit` branch of `build`).
  /// Bumping on it would rebuild the whole grid under the finger, which is
  /// exactly the regression the static cache was added to stop.
  void _keySetChanged(String id) {
    if (id == widget.dashboardController.editSession?.editing.id) {
      return;
    }
    _widgetsRevision++;
  }

  /// Drops [id] from the item map — the ONE way an item leaves it.
  ///
  /// Five call sites remove items (two in `build`, two in the resize branch of
  /// `_onMoveUpdate`, one in its transform branch); a sixth one that forgot the
  /// revision would silently resurrect the defect this wave fixes, so they all
  /// go through here.
  void _removeWidget(String id) {
    if (_widgetsMap.remove(id) != null) {
      _keySetChanged(id);
    }
  }

  /// Empties the item map and both caches.
  ///
  /// „Cleared" and „invalidated" cannot drift apart if there is one way to do
  /// both — `reassemble` used to clear the map WITHOUT invalidating the static
  /// cache, so a hot reload redrew the stale list.
  void _clearWidgets() {
    if (_widgetsMap.isNotEmpty) {
      _widgetsMap.clear();
      _widgetsRevision++;
    }
    _invalidateStaticCache();
  }

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

    _keySetChanged(id);
  }

  final Map<String, GlobalKey<_DashboardItemWidgetState<T>>> _keys = {};

  late int startIndex, endIndex;

  /// The slot background as ONE subtree that is MOVED, not rebuilt.
  ///
  /// The slots are positioned in CONTENT space and the whole layer is offset by a
  /// single `AnimatedBuilder` over the viewport offset — the same trick every item
  /// has always used (`dashboard_item_widget.dart:299-313`). Until this, `top`
  /// carried `- pixels`, so `pixels` belonged to the cache key and each frame of a
  /// scroll rebuilt the entire layer: 600 `Positioned` > `RepaintBoundary` >
  /// `Builder` > `Container` subtrees per frame on a phone frame, measured as
  /// 56,6 % of the build time of a scroll frame (7,0 ms of 12,4 ms).
  ///
  /// `clipBehavior: Clip.none` on the inner `Stack` is mandatory: its box is a
  /// COORDINATE FRAME, not a viewport, and the slots of the cache band
  /// deliberately stand outside it. The visible boundary is unchanged — the outer
  /// `Stack` still clips with `Clip.hardEdge`.
  Widget _buildBackgroundLayer() {
    final slots = _buildBackgroundSlots();
    // POSITIONED even when empty: a non-positioned child sizes the grid's
    // `Stack`, and under loose constraints a bare `SizedBox.shrink()` made it
    // 0×0 — its `Clip.hardEdge` then cut away every item (`T-PV2-12`).
    if (slots.isEmpty) {
      return const Positioned.fill(child: SizedBox.shrink());
    }

    return AnimatedBuilder(
      animation: viewportOffset,
      child: RepaintBoundary(
        child: Stack(clipBehavior: Clip.none, children: slots),
      ),
      builder: (context, child) {
        return Positioned(
          left: 0,
          right: 0,
          top: -pixels,
          height: _backgroundLayerHeight,
          child: child!,
        );
      },
    );
  }

  List<Widget> _buildBackgroundSlots() {
    final isEditing = widget.dashboardController.isEditing;

    // The rows the viewport really shows right now.
    final visibleStartY = (pixels / verticalSlotEdge).floor();
    final visibleEndY = ((pixels + height) / verticalSlotEdge).ceil();

    // The layer is rebuilt when the viewport LEAVES its band — not when the band
    // would move. Taking `startIndex`/`endIndex` as the key was not enough: both
    // are `floor()`/`ceil()` of the offset, so each of them crosses a row every
    // ~2,5 frames of a 24 px scroll and between the two of them the layer still
    // came out on 8 of 10 frames (measured). Hysteresis makes that once per
    // `cacheExtend` of travel: ~20 frames at the same step, with the band being
    // exactly the one the items use, so the first build draws the same slots in
    // the same places as before this wave.
    if (_cachedBackgroundWidgets != null &&
        _lastIsEditing == isEditing &&
        visibleStartY >= _backgroundStartY &&
        visibleEndY <= _backgroundEndY) {
      return _cachedBackgroundWidgets!;
    }

    _backgroundStartY =
        ((pixels - widget.cacheExtend) / verticalSlotEdge).floor();
    _backgroundEndY =
        ((pixels + height + widget.cacheExtend) / verticalSlotEdge).ceil();

    final res = <Widget>[];

    final slotCount = widget.dashboardController.slotCount;
    var l =
        viewportDelegate.padding.left + (viewportDelegate.crossAxisSpace / 2);
    var t = viewportDelegate.padding.top + (viewportDelegate.mainAxisSpace / 2);
    var h = verticalSlotEdge - viewportDelegate.mainAxisSpace;

    // The builder resolves the item standing on a slot through the item
    // controller, so it needs it before the first call.
    widget.slotBackground!._itemController =
        widget.dashboardController.itemController;

    var bottom = 0.0;

    for (var y = _backgroundStartY; y <= _backgroundEndY; y++) {
      for (var x = 0; x < slotCount; x++) {
        // The user's builder decides whether the slot draws at all, and it is now
        // asked ONCE per band — it used to sit inside a `Builder`, i.e. be asked
        // again on every frame. A slot it answers `null` for produces NO widget:
        // a cockpit standing on a wallpaper returns `null` for every slot, and used
        // to pay for a full `Positioned` > `RepaintBoundary` > `Builder` >
        // `Container` for each one of them.
        final background = widget.slotBackground!._build(context, x, y);
        if (background == null) {
          continue;
        }

        // Use virtual columns aware positioning
        var columnPos = widget.dashboardController.getColumnPosition(x);
        var columnWidth = widget.dashboardController.getColumnWidth(x);
        var w = columnWidth - viewportDelegate.crossAxisSpace;
        var top = y * verticalSlotEdge + t;

        res.add(Positioned(
          left: columnPos + l,
          top: top,
          width: w,
          height: h,
          child: background,
        ));

        if (top + h > bottom) {
          bottom = top + h;
        }
      }
    }

    _backgroundLayerHeight = bottom;
    _cachedBackgroundWidgets = res;
    _lastIsEditing = isEditing;

    return res;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dashboardController._rebuild) {
      _clearWidgets();
      widget.dashboardController._rebuild = false;
    }

    // Check if slot dimensions changed and invalidate widget positions if needed
    final newSlotEdge = widget.dashboardController.slotEdge;
    final newVerticalSlotEdge = widget.dashboardController.verticalSlotEdge;

    if (slotEdge != newSlotEdge || verticalSlotEdge != newVerticalSlotEdge) {
      _clearWidgets();
    }

    slotEdge = newSlotEdge;
    verticalSlotEdge = newVerticalSlotEdge;

    // No geometry, nothing to lay out. The band below divides by
    // `verticalSlotEdge`, and at zero `startY` would be an infinity that
    // `floor()` refuses — so this is also the one guard that keeps a stack built
    // before `_setSizes` from throwing instead of drawing nothing.
    if (verticalSlotEdge <= 0 || slotEdge <= 0) {
      return const SizedBox.shrink();
    }

    var startPixels = (viewportOffset.pixels) - widget.cacheExtend;
    var startY = (startPixels / verticalSlotEdge).floor();

    startIndex = widget.dashboardController.getIndex([0, startY]);

    var endPixels = viewportOffset.pixels + height + widget.cacheExtend;
    var endY = (endPixels / verticalSlotEdge).ceil();
    endIndex = widget.dashboardController
        .getIndex([widget.dashboardController.slotCount - 1, endY]);

    // Only the slots of the visible rows are looked at, so the cost follows
    // the viewport and not the grid. Until now the stack also walked the WHOLE
    // index before and after the viewport, on every build — every scroll and
    // drag frame (`tool/bench_index_map.dart`: 383 µs → 19 µs per build on a
    // 600-item grid). Set order is slot order, the same z-order as before.
    final needs = widget.dashboardController._slotIndex
        .itemsInRange(startIndex, endIndex);

    var edit = widget.dashboardController.editSession?.editing;

    // Everything else leaves the map: items scrolled out (except the one being
    // edited, which stays even when dragged out of the viewport), and items
    // DELETED from the controller, edited or not — `buildPositioned` would
    // dereference `_items[id]!` on a dead id.
    final live = widget.dashboardController.itemController._items;
    for (final gone in _widgetsMap.keys
        .where((id) =>
            !live.containsKey(id) || (!needs.contains(id) && id != edit?.id))
        .toList()) {
      _removeWidget(gone);
    }

    for (var n in needs) {
      if (!_widgetsMap.containsKey(n)) {
        addWidget(n);
      }
    }

    if (edit != null && !_widgetsMap.containsKey(edit.id)) {
      _removeWidget(edit.id);
      _keys.remove(edit.id);
      addWidget(edit.id);
    }

    Widget result = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (widget.slotBackground != null) _buildBackgroundLayer(),

        // Background painter should be below widgets to not block interactions
        if (widget.dashboardController.isEditing)
          Positioned(
            top: viewportDelegate.padding.top,
            left: viewportDelegate.padding.left,
            width: viewportDelegate.constraints.maxWidth -
                viewportDelegate.padding.vertical,
            height: viewportDelegate.constraints.maxHeight -
                viewportDelegate.padding.horizontal,
            child: IgnorePointer(
              // Important: don't block interactions
              child: Builder(builder: (context) {
                return _AnimatedBackgroundPainter(
                    layoutController: widget.dashboardController,
                    editModeSettings: widget.editModeSettings,
                    offset: viewportOffset);
              }),
            ),
          ),

        // Static layer - widgets that don't change during editing
        ..._buildStaticWidgets(),

        // Dynamic overlay layer - only currently editing widget (on top)
        if (widget.dashboardController.editSession?.editing != null)
          _buildEditingOverlay(),

        if (widget.dashboardController.itemController._items.isEmpty &&
            !widget.dashboardController._isEditing)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              top: 0,
              child: widget.emptyPlaceholder ?? Container()),
      ],
    );

    if (widget.dashboardController.isEditing &&
        widget.editModeSettings.scrollWhileEditing) {
      result = _buildEditGestures(result);
    } else if (widget.dashboardController.isEditing) {
      result = GestureDetector(
        // Opaque behavior żeby przechwytywać gesty przed Scrollable
        behavior: HitTestBehavior.opaque,
        // The item and the edge are picked where the pointer went DOWN. With
        // the default `start`, `onPanStart` reports the position after the
        // touch slop (18 px), so a grab near an edge landed outside the item
        // or on the wrong edge.
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: widget.editModeSettings.panEnabled
            ? (panStart) {
                _onMoveStart(panStart.localPosition);
              }
            : null,
        onPanUpdate: widget.editModeSettings.panEnabled
            ? (u) {
                if (widget.dashboardController.editSession != null) {
                  setSpeed(u.localPosition);
                  _onMoveUpdate(u.localPosition);
                }
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
        onLongPressMoveUpdate: widget.editModeSettings.longPressEnabled
            ? (u) {
                if (widget.dashboardController.editSession != null) {
                  setSpeed(u.localPosition);
                  _onMoveUpdate(u.localPosition);
                }
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

  /// The edit-mode gestures of `scrollWhileEditing`: see
  /// [_EditDragGestureRecognizer].
  Widget _buildEditGestures(Widget child) {
    final settings = widget.editModeSettings;
    if (!settings.panEnabled && !settings.longPressEnabled) {
      return child;
    }
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _EditDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EditDragGestureRecognizer>(
          () => _EditDragGestureRecognizer(debugOwner: this),
          (recognizer) => recognizer
            ..hitTest = _editHitAt
            ..touchPickUpDelay = settings.touchPickUpDelay
            ..onStart = _onEditDragStart
            ..onUpdate = _onEditDragUpdate
            ..onEnd = _onMoveEnd,
        ),
      },
      child: child,
    );
  }

  _EditHit _editHitAt(Offset local) {
    final hit = _hitAt(local);
    if (hit == null || hit.holdOffset.dx < 0 || hit.holdOffset.dy < 0) {
      return _EditHit.none;
    }
    return hit.onResizeButton ? _EditHit.handle : _EditHit.tile;
  }

  void _onEditDragStart(Offset local, Offset global) {
    _onMoveStart(local);
    if (_editing == null) {
      return;
    }
    _lastLocal = local;
    final carousel = widget.dashboardController.itemController._carouselOffset;
    _startPageOffset = carousel?.value;
    _listenedCarousel = carousel?..addListener(_onCarouselMoved);
    _publishPointer(global);
  }

  void _onEditDragUpdate(Offset local, Offset global) {
    if (_editing == null || widget.dashboardController.editSession == null) {
      return;
    }
    _lastLocal = local;
    _publishPointer(global);
    _updateAutoScroll(local);
    _onMoveUpdate(local + _pageShift);
  }

  void _publishPointer(Offset global) {
    widget.dashboardController.itemController._dragPointer.value =
        _DragPointer(global, widget.editModeSettings);
  }

  /// Where the dragging pointer last was, in this stack's coordinates AS THE
  /// POINTER SEES THEM: the transform of every later event is the one recorded
  /// by the hit test on `down`, so once the carousel has moved the grid, this
  /// still points into the section the drag started in. [_pageShift] is the
  /// correction, like `pixels - _startScrollPixels` is for the vertical scroll.
  Offset? _lastLocal;

  /// The carousel's offset when the drag started, `null` outside a carousel.
  double? _startPageOffset;
  ValueListenable<double>? _listenedCarousel;

  Offset get _pageShift {
    final carousel = _listenedCarousel;
    if (carousel == null || _startPageOffset == null) {
      return Offset.zero;
    }
    return Offset(carousel.value - _startPageOffset!, 0);
  }

  /// The carousel moved under a pointer that may stand still: the item
  /// follows the content, not the stale position of the last event.
  void _onCarouselMoved() {
    if (_editing != null && _lastLocal != null) {
      _onMoveUpdate(_lastLocal! + _pageShift, force: true);
    }
  }

  Ticker? _autoScrollTicker;

  /// Auto-scroll speed in pixels per second; negative scrolls up.
  double _autoScrollVelocity = 0;
  Duration _lastAutoScrollTick = Duration.zero;

  /// Sets the auto-scroll speed from how deep [local] is in an edge zone:
  /// zero at its inner border, [EditModeSettings.autoScrollMaxSpeed] at the
  /// edge, growing with the square of the depth.
  void _updateAutoScroll(Offset local) {
    final settings = widget.editModeSettings;
    final extent = viewportDelegate.constraints.maxHeight;
    var depth = 0.0;
    if (settings.autoScroll && extent.isFinite) {
      final edge = settings._edgeFor(extent);
      if (local.dy < edge) {
        depth = -(edge - local.dy) / edge;
      } else if (local.dy > extent - edge) {
        depth = (local.dy - (extent - edge)) / edge;
      }
    }
    depth = depth.clamp(-1.0, 1.0);
    _autoScrollVelocity = settings.autoScrollMaxSpeed * depth * depth.abs();

    if (_autoScrollVelocity == 0) {
      _stopAutoScroll();
    } else {
      final ticker = _autoScrollTicker ??= createTicker(_onAutoScrollTick);
      if (!ticker.isActive) {
        _lastAutoScrollTick = Duration.zero;
        ticker.start();
      }
    }
  }

  void _stopAutoScroll() {
    _autoScrollVelocity = 0;
    _autoScrollTicker?.stop();
  }

  /// One step of the auto-scroll: speed × time since the last frame, so the
  /// speed does not depend on the refresh rate.
  ///
  /// `jumpTo` applies no boundary of the physics, so the range is clamped here.
  /// While an item moves, `Dashboard._setNewOffset` extends the range by one
  /// row past the end, which is where an item can be dragged to grow the
  /// grid; the drop recomputes it, growing it or correcting `pixels` back into
  /// it.
  void _onAutoScrollTick(Duration elapsed) {
    final dt = (elapsed - _lastAutoScrollTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastAutoScrollTick = elapsed;
    if (dt <= 0 || _editing == null || _lastLocal == null) {
      return;
    }

    final position = viewportOffset;
    var minExtent = 0.0;
    var maxExtent = double.infinity;
    if (position is ScrollPosition && position.hasContentDimensions) {
      minExtent = position.minScrollExtent;
      maxExtent = position.maxScrollExtent;
    }
    final target = (pixels + _autoScrollVelocity * dt)
        .clamp(min(minExtent, pixels), max(maxExtent, pixels))
        .toDouble();
    if (target == pixels) {
      return;
    }
    viewportOffset.jumpTo(target);
    // The pointer may stand still: without this the item stays where the last
    // event left it while the content moves away under it.
    _onMoveUpdate(_lastLocal! + _pageShift, force: true);
  }

  // Cache for static widgets
  List<Widget>? _cachedStaticWidgets;
  String? _lastEditingId;
  int? _lastStaticRevision;

  // Cache for background grid
  List<Widget>? _cachedBackgroundWidgets;
  bool? _lastIsEditing;

  /// Rows the cached background layer covers, and the height of its frame.
  int _backgroundStartY = 0;
  int _backgroundEndY = 0;
  double _backgroundLayerHeight = 0.0;

  List<Widget> _buildStaticWidgets() {
    final currentEditingId = widget.dashboardController.editSession?.editing.id;

    // Use the cache only for the KEY SET it was built from.
    //
    // The revision is the half that was missing: the condition used to be
    // `_lastEditingId == currentEditingId` alone, and outside edit mode both are
    // `null` — so a scroll that pulled new items into `_widgetsMap` (paying for
    // `itemBuilder` in `addWidget`) still handed the `Stack` the OLD list. Below
    // the first band the grid went empty and never filled again; measured on a
    // phone as 5 → 2 → 0 items on screen after three screen-height scrolls, with
    // the stale four coming back on the way up.
    if (_cachedStaticWidgets != null &&
        _lastEditingId == currentEditingId &&
        _lastStaticRevision == _widgetsRevision) {
      return _cachedStaticWidgets!;
    }

    _cachedStaticWidgets = _widgetsMap.entries
        .where((element) => element.value[2] != currentEditingId)
        .map((e) {
      return buildPositioned(e.value);
    }).toList();

    _lastEditingId = currentEditingId;
    _lastStaticRevision = _widgetsRevision;
    return _cachedStaticWidgets!;
  }

  void _invalidateStaticCache() {
    _cachedStaticWidgets = null;
    _lastEditingId = null;
    _lastStaticRevision = null;
    _cachedBackgroundWidgets = null;
    _lastIsEditing = null;
  }

  Widget _buildEditingOverlay() {
    final editingId = widget.dashboardController.editSession?.editing.id;
    if (editingId == null || !_widgetsMap.containsKey(editingId)) {
      return const SizedBox.shrink();
    }

    return buildPositioned(_widgetsMap[editingId]!);
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
    _clearWidgets();
    super.reassemble();
  }

  double speed = 0;

  Offset holdOffset = Offset.zero;

  /// The item under [local] and how a drag from there edits it, or `null`
  /// over an empty slot.
  ///
  /// The one copy of this arithmetic: [_onMoveStart] picks the item and the
  /// edges with it, and the recognizer of `scrollWhileEditing` decides with it
  /// whether to enter the arena at all, so the two can never disagree. A
  /// negative [holdOffset] means the pointer is on the item's slot but in the
  /// gap before the item.
  ({
    String id,
    List<AxisDirection>? directions,
    bool onResizeButton,
    Offset holdOffset,
  })? _hitAt(Offset local) {
    // Oblicz pozycję względną (bez padding)
    var holdGlobal = Offset(local.dx - viewportDelegate.padding.left,
        local.dy - viewportDelegate.padding.top);

    var x = widget.dashboardController
        .getColumnFromPositionExact(local.dx - viewportDelegate.padding.left);
    var y =
        (local.dy + pixels - viewportDelegate.padding.top) ~/ verticalSlotEdge;

    var e = widget.dashboardController
        ._slotIndex[widget.dashboardController.getIndex([x, y])];

    if (e is! String) {
      return null;
    }

    var directions = <AxisDirection>[];
    var current = widget.dashboardController._layouts![e]!._currentPosition(
        slotEdge: slotEdge,
        viewportDelegate: viewportDelegate,
        verticalSlotEdge: verticalSlotEdge);

    // Popraw obliczenia pozycji elementu - current.x już zawiera padding.left
    var itemGlobal = _ItemCurrentPosition(
        x: current.x - viewportDelegate.padding.left,
        y: current.y - viewportDelegate.padding.top - pixels,
        height: current.height,
        width: current.width);

    final holdOffset = holdGlobal - Offset(itemGlobal.x, itemGlobal.y);
    if (holdGlobal.dx < itemGlobal.x || holdGlobal.dy < itemGlobal.y) {
      return (
        id: e,
        directions: null,
        onResizeButton: false,
        holdOffset: holdOffset
      );
    }

    // Sprawdź czy kliknięcie jest na przycisku skalowania (bottom-right)
    bool onResizeButton = false;
    if (widget.editModeSettings.resizeHandleBuilder != null) {
      // Powiększony obszar detekcji dla ekranu dotykowego (50x50px)
      // Przycisk wizualnie jest mniejszy, ale strefa dotykowa większa
      double buttonLeft = itemGlobal.endX - 50;
      double buttonTop = itemGlobal.endY - 50;
      double buttonRight = itemGlobal.endX;
      double buttonBottom = itemGlobal.endY;

      onResizeButton = holdGlobal.dx >= buttonLeft &&
          holdGlobal.dx <= buttonRight &&
          holdGlobal.dy >= buttonTop &&
          holdGlobal.dy <= buttonBottom;
    }

    // Lewa krawędź
    double leftEdge = itemGlobal.x + widget.editModeSettings.resizeCursorSide;
    if (leftEdge > holdGlobal.dx) {
      directions.add(AxisDirection.left);
    }

    // Górna krawędź
    double topEdge = itemGlobal.y + widget.editModeSettings.resizeCursorSide;
    if (topEdge > holdGlobal.dy) {
      directions.add(AxisDirection.up);
    }

    // Prawa krawędź
    double rightEdge =
        itemGlobal.endX - widget.editModeSettings.resizeCursorSide;
    if (rightEdge < holdGlobal.dx || onResizeButton) {
      directions.add(AxisDirection.right);
    }

    // Dolna krawędź
    double bottomEdge =
        itemGlobal.endY - widget.editModeSettings.resizeCursorSide;
    if (bottomEdge < holdGlobal.dy || onResizeButton) {
      directions.add(AxisDirection.down);
    }

    return (
      id: e,
      directions: directions.isEmpty ? null : directions,
      onResizeButton: onResizeButton,
      holdOffset: holdOffset
    );
  }

  void _onMoveStart(Offset local) {
    final hit = _hitAt(local);

    if (hit != null) {
      final e = hit.id;
      _editing = widget.dashboardController._layouts![e]!;

      if (hit.holdOffset.dx < 0 || hit.holdOffset.dy < 0) {
        _editing = null;
        return;
      }

      _holdDirections = hit.directions;
      _moveStartOffset = local;
      _startScrollPixels = pixels;
      widget.dashboardController.startEdit(e, _holdDirections == null);
      widget.dashboardController.itemController._liftedItem.value = e;

      holdOffset = hit.holdOffset;

      var l = widget.dashboardController._layouts![e];
      widget.dashboardController.editSession!.editing._originSize = [
        l!.width,
        l.height
      ];
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

  /// [force] skips the throttling: the auto-scroll and the carousel call this
  /// once per frame when the content moves, and dropping such a call leaves
  /// the item behind until the pointer moves again.
  void _onMoveUpdate(Offset local, {bool force = false}) {
    if (_editing == null) {
      return;
    }

    // Throttling - ogranicz częstotliwość aktualizacji do 60 FPS
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && _lastMoveUpdate != null && now - _lastMoveUpdate! < 16) {
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
          scrollDifference: scrollDifference,
          hysteresis: widget.editModeSettings.resizeHysteresis);

      if (resizeMoveResult.isChanged) {
        _moveStartOffset = _moveStartOffset! + resizeMoveResult.startDifference;

        // Only call setState if other widgets were affected
        // Don't rebuild for just the editing widget - it uses transform feedback
        if (differences.isNotEmpty) {
          setState(() {
            _removeWidget(_editing!.id);
            for (var r in differences) {
              _removeWidget(r);
            }
            _invalidateStaticCache();
          });
        }

        if (_editing!._endIndex > (e)) {
          widget.shouldCalculateNewDimensions();
        }
      }
    } else {
      var resizeMoveResult = _editing!._transformUpdate(
          local - _moveStartOffset!, pixels - _startScrollPixels!, holdOffset);

      if (resizeMoveResult != null && resizeMoveResult.isChanged) {
        // Real position change - element snapped to new grid position
        _moveStartOffset = _moveStartOffset! + resizeMoveResult.startDifference;

        // For transform changes, only setState for position update
        // Don't invalidate cache unless absolutely necessary
        setState(() {
          // Only the dragged item leaves the map, and `_removeWidget` knows not
          // to bump the revision for it — so the static layer of the OTHER items
          // keeps its cache and is not rebuilt under the finger.
          _removeWidget(_editing!.id);
        });

        if (_editing!._endIndex > (e)) {
          widget.shouldCalculateNewDimensions();
        }
      }
      // If resizeMoveResult is null, it's just visual transform - no rebuild needed
      // Visual feedback is handled by AnimatedBuilder listening to _transform ValueNotifier
    }
  }

  void _onMoveEnd() {
    if (_editing != null && _lastLocal != null && !_editingResize) {
      // The drop lands where the pointer is NOW. Both throttles run on the
      // wall clock, so after the auto-scroll or a section change the last
      // slot check may be up to a frame old; this one is not skipped.
      _editing!._lastTransformUpdate = null;
      _onMoveUpdate(_lastLocal! + _pageShift, force: true);
    }
    _lastMoveUpdate = null; // Reset on move end
    _stopAutoScroll();
    _listenedCarousel?.removeListener(_onCarouselMoved);
    _listenedCarousel = null;
    _startPageOffset = null;
    _lastLocal = null;
    widget.dashboardController.itemController._dragPointer.value = null;
    widget.dashboardController.itemController._liftedItem.value = null;
    _editing?._key = _keys[_editing!.id]!;
    _editing?._key.currentState
        ?._setLast(_editing!._transform.value, _editing!._resizePosition.value)
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
