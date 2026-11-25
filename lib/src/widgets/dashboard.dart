part of '../dashboard_base.dart';

///
typedef DashboardItemBuilder<T extends DashboardItem> = Widget Function(T item);

/// A list of widget arranged with hand or initially.
///
/// [Dashboard] is scrolling widget that contains items which can
/// edited by size and place.
///
/// In general, it is used to allow the user to control the locations and
/// dimensions of the views(e.g. task list, charts etc.) in applications
/// that have many different views.
///
/// Dashboard divides the viewport to a certain number of slots
/// on the horizontal and places the items according to these slots.
///
/// The slot width is determined by [slotCount] value.
/// And slot height determined by [slotHeight] or [slotAspectRatio].
/// In default slots are square.
///
/// [dashboardItemController] determines the layouts of widgets to be displayed
/// in initial state.
/// This controller is also used to add/delete widget and handle layout changes.
class Dashboard<T extends DashboardItem> extends StatefulWidget
    implements _DashboardConfig<T> {
  /// A list of widget arranged with hand or initially.
  Dashboard(
      {super.key,
      required this.itemBuilder,
      required this.dashboardItemController,
      this.slotCount = 8,
      this.scrollController,
      this.primary = false,
      this.physics,
      this.dragStartBehavior,
      this.scrollBehavior,
      this.cacheExtend = 500,
      this.verticalSpace = 8,
      this.horizontalSpace = 8,
      this.padding = const EdgeInsets.all(0),
      this.shrinkToPlace = true,
      this.slideToTop = true,
      this.slotAspectRatio,
      this.slotHeight,
      EditModeSettings? editModeSettings,
      this.textDirection = TextDirection.ltr,
      this.errorPlaceholder,
      this.loadingPlaceholder,
      this.emptyPlaceholder,
      this.absorbPointer = true,
      this.animateEverytime = true,
      this.itemStyle = const ItemStyle(),
      this.scrollToAdded = true,
      this.slotBackgroundBuilder,
      this.onGridDimensionsChanged,
      this.virtualColumnsConfig,
      this.maxRows,
      this.isSizeAllowed,
      this.onEmptySlotTap,
      this.swapOnDrop = false,
      this.onItemMoveUpdate,
      this.onItemDropOutside})
      : assert(maxRows == null || maxRows > 0),
        assert((slotHeight == null && slotAspectRatio == null) ||
            !(slotHeight != null && slotAspectRatio != null)),
        editModeSettings = editModeSettings ?? EditModeSettings();

  /// If [slotBackgroundBuilder] is not null, the background of the slots
  /// is drawn with the  [SlotBackgroundBuilder.build] method.
  ///
  /// The [SlotBackgroundBuilder.build] method is called for each slot that
  /// is visible on the screen and in the cache area.
  @override
  final SlotBackgroundBuilder<T>? slotBackgroundBuilder;

  /// If [scrollToAdded] is true, when a new item is added, the viewport
  /// scrolls to the added item.
  @override
  final bool scrollToAdded;

  /// [slotAspectRatio] determines slots height. Slot width determined by
  /// viewport width and [slotCount].
  @override
  final double? slotAspectRatio;

  /// [slotHeight] determines slots height by fixed length.
  @override
  final double? slotHeight;

  /// In edit mode, item position changes due to resizing/moving are animated.
  ///
  /// Also, changes due to slotCount changes are animated in edit mode.
  ///
  /// If [animateEverytime] item positions change with animation on
  /// slotCount changes. Else the changes are not animated.
  @override
  final bool animateEverytime;

  /// Absorb item gestures on edit mode.
  @override
  final bool absorbPointer;

  /// Each existing [DashboardItem] in the [dashboardItemController] must
  /// added to widget tree.
  ///
  /// [itemBuilder] callback takes a argument of [DashboardItem].
  /// [DashboardItem.itemLayout] carries the latest [ItemLayout].
  /// [itemBuilder] must return non-null Widget instance. The callback will be
  /// called when widget created or item editing started (for only editing item)
  /// or change item layout (for only changed items).
  ///
  /// [cacheExtend] determines when the widget will creating / removing in
  /// the widget tree.
  @override
  final DashboardItemBuilder<T> itemBuilder;

  /// The viewport has an area before and after the visible area to cache items
  /// that are about to become visible when the user scrolls.
  /// Items that fall in this cache area are laid out even though they are
  /// not (yet) visible on screen. The [cacheExtent] describes how many pixels
  /// the cache area extends before the leading edge and after the trailing
  /// edge of the viewport.
  /// The total extent, which the viewport will try to cover with children,
  /// is  [cacheExtent] before the leading edge + extent of the
  /// main axis + [cacheExtent] after the trailing edge.
  @override
  final double cacheExtend;

  /// When in Layout edit mode is true, some paintings/drawings are made on the
  /// viewport background and items (widgets) foreground.
  ///
  /// [editModeSettings] are used for settings related to the drawing, painting
  /// and animations during editing.
  ///
  /// For more information about settings see [EditModeSettings].
  @override
  final EditModeSettings editModeSettings;

  /// If the [dashboardItemController] uses a [DashboardItemStorageDelegate],
  /// the loading of the items initially is done with a FutureOr function.
  ///
  /// If the function returns a Future, this loading may take a while.
  /// In during loading, [Dashboard] shows [loadingPlaceholder].
  ///
  /// Default [loadingPlaceholder] is a centered circular process indicator.
  @override
  final Widget? loadingPlaceholder;

  /// If the function don't have any data then it should display something
  /// In empty data, [Dashboard] shows [emptyPlaceholder].
  ///
  /// Default [emptyPlaceholder] is a sizedBox means just empty space.
  @override
  final Widget? emptyPlaceholder;

  /// If the [dashboardItemController] uses a [DashboardItemStorageDelegate],
  /// the loading of the items initially is done with a FutureOr function.
  ///
  /// If the function throws a exception [Dashboard] will call
  /// [errorPlaceholder] and shows returned widget.
  @override
  final Widget Function(Object error, StackTrace stackTrace)? errorPlaceholder;

  /// [dashboardItemController] is dashboard items controller.
  /// The controller determines initial [DashboardItem]s and add / delete
  /// operations are done with this controller.
  ///
  /// Also storage operations are made with the [DashboardItemStorageDelegate]
  /// of the controller (if non-null).
  @override
  final DashboardItemController<T> dashboardItemController;

  /// Vertical slot count.
  @override
  final int slotCount;

  /// [Scrollable] widget scrollController.
  final ScrollController? scrollController;

  /// When `true` and [scrollController] is null, the grid scrolls on
  /// `PrimaryScrollController.maybeOf(context)` — the inner position of an
  /// enclosing `NestedScrollView` (One UI band), so dragging the grid also
  /// collapses and expands the band above it.
  ///
  /// Default `false`: a bare `Scrollable` never adopts the primary controller
  /// (`scrollable.dart:590-591`, Flutter 3.47), and the carousel, the layout
  /// editor and the device-tile tabs rely on that — under a band they must
  /// keep scrolling on their own position. With `true` and no
  /// `PrimaryScrollController` above, the grid behaves exactly as with `false`.
  final bool primary;

  /// [Scrollable] widget scrollPhysics.
  final ScrollPhysics? physics;

  /// [Scrollable] widget dragStartBehavior.
  final DragStartBehavior? dragStartBehavior;

  /// [Scrollable] widget scrollBehavior.
  final ScrollBehavior? scrollBehavior;

  /// Horizontal gap between two items.
  ///
  /// If the items startX equal 0 or items endX equal slotCount the gap
  /// is not placed. (Edges touching the edges of viewport excluding padding.)
  @override
  final double horizontalSpace;

  /// Vertical gap between two items.
  ///
  /// If the items startY equal 0 or items endY is biggest Y in the Dashboard,
  /// the gap is not placed. (Edges touching the edges of
  /// viewport excluding padding.)
  @override
  final double verticalSpace;

  /// [padding] is the spacing between items and Dashboard outer edges.
  @override
  final EdgeInsetsGeometry padding;

  /// When adding a new item, item dimensions editing or in the initial
  /// re-arranging, items trying to place certain position. When the item not
  /// fit to the position (e.g. conflict with another item), if [shrinkToPlace]
  /// is true item dimensions trying to shrink, else Dashboard decide that item
  /// not placed to the position.
  ///
  /// Shrinking pays attention minWidth / minHeight.
  @override
  final bool shrinkToPlace;

  /// Initially try slide items to top.
  ///
  /// If [slideToTop] is true, Initially empty slots at the top are tried
  /// to be filled with items that starting from the top.
  @override
  final bool slideToTop;

  /// [padding] resolved with [textDirection].
  @override
  final TextDirection textDirection;

  /// Each item is wrapped by a [Material]. Material's parameters can be
  /// specified with [itemStyle].
  ///
  /// Look [Material] documentation for more.
  @override
  final ItemStyle itemStyle;

  /// Callback to notify when grid dimensions change
  @override
  final void Function(GridDimensions dimensions)? onGridDimensionsChanged;

  /// Virtual columns configuration for disabling specific columns.
  /// When set, specified columns cannot have items placed on them.
  ///
  /// Example:
  /// ```dart
  /// VirtualColumnsConfig(
  ///   disabledColumns: [7, 15], // columns 7 and 15 are disabled
  ///   disabledColumnWidth: 40.0, // disabled columns are 40px wide
  /// )
  /// ```
  @override
  final VirtualColumnsConfig? virtualColumnsConfig;

  /// The row ceiling: no item ever occupies a row `>= maxRows`.
  ///
  /// `null` (the default) is the usual grid that grows downwards. When set,
  /// the grid is a fixed board of [slotCount] x [maxRows] slots, as a wall
  /// panel's screen: moving and resizing never take an item past the last
  /// row (a drag below it ends on the last row the item fits in), shrinking
  /// on a move and the placement of added items stay above it, the edit-mode
  /// background paints exactly [maxRows] rows and the grid never scrolls
  /// past them.
  ///
  /// [DashboardItemController.add] and [DashboardItemController.addAll] throw
  /// [DashboardNoSpaceException] when an item has no free place within the
  /// ceiling; [DashboardItemController.canPlace] checks a layout first. An
  /// item of the initial load that has no place within the ceiling is left
  /// out of the grid (and out of [DashboardItemController.items]); the
  /// storage delegate is not told.
  ///
  /// Read on every build, without re-laying the grid out: items already past
  /// a lowered ceiling keep their place until they are moved.
  @override
  final int? maxRows;

  /// Which item sizes are allowed, as `width x height` in slots.
  ///
  /// `null` (the default) allows every size within an item's min/max. When
  /// set:
  ///
  /// * a resize only ever takes an item to a size this returns `true` for.
  ///   While a handle is dragged, a refused size is skipped: the item keeps
  ///   the last allowed size until the pointer reaches the next allowed one,
  ///   and an edge whose next allowed size is out of reach does not move;
  /// * a neighbour pushed by a resize is never shrunk to a refused size (the
  ///   resize does not happen instead);
  /// * shrinking to fit ([shrinkToPlace], [EditModeSettings.shrinkOnMove])
  ///   picks the largest allowed size that fits; when none fits, the item is
  ///   not placed there;
  /// * an item keeps its OWN size even if it is refused: added, loaded or
  ///   moved at the size it has, it is not checked (only
  ///   [DashboardItemController.canPlace] checks it).
  ///
  /// A drag of a corner handle takes the horizontal step first, then the
  /// vertical one, each to an allowed size; a size reachable only by both at
  /// once (1x1 to 2x2 when neither 2x1 nor 1x2 is allowed) is not reached.
  @override
  final bool Function(int width, int height)? isSizeAllowed;

  /// Called with the column and row of an empty slot the user tapped.
  ///
  /// A tap — not a drag, a long press or a scroll — on a slot no item
  /// occupies, in and out of edit mode. A tap on an item, in the gap of an
  /// occupied slot, on a disabled virtual column, in the padding, or on a row
  /// at or past [maxRows] does not call it. `null` (the default) adds no
  /// gesture recognizer at all.
  @override
  final void Function(int x, int y)? onEmptySlotTap;

  /// Whether dropping an item exactly onto another item of the same size
  /// swaps the two.
  ///
  /// When the slot the dragged item is dropped on (where its top-left corner
  /// is under the pointer) is the top-left slot of ONE other item with the
  /// dragged item's width and height, that item moves to where the dragged
  /// one was picked up and the dragged one takes its place. Both are reported
  /// to [DashboardItemStorageDelegate.onItemsUpdated] in one call. Default
  /// `false`.
  @override
  final bool swapOnDrop;

  /// Called while an item is MOVED in edit mode (not resized) with the
  /// identifier of the item and the pointer's position in GLOBAL coordinates,
  /// on every pointer update, also while the pointer is outside the grid; and
  /// once with `null` when the move ends (dropped or cancelled).
  ///
  /// Lets a host show its own drop targets around the grid (the tabs of other
  /// boards, a bin). `null` (the default) changes nothing.
  @override
  final void Function(String id, Offset? globalPosition)? onItemMoveUpdate;

  /// Called when a moved item is released with the pointer OUTSIDE the grid's
  /// box, with the item's identifier and the pointer's global position.
  ///
  /// Returning `true` means the host took the drop: the item goes back to the
  /// slot it was picked up from, no swap is made ([swapOnDrop]) and nothing is
  /// reported to [DashboardItemStorageDelegate.onItemsUpdated] — the host
  /// moves the item elsewhere itself. Returning `false`, or `null` (the
  /// default), drops it as usual, where it stands. A resize never calls it.
  @override
  final bool Function(String id, Offset globalPosition)? onItemDropOutside;

  @override
  State<Dashboard<T>> createState() => _DashboardState<T>();
}

class _DashboardState<T extends DashboardItem> extends State<Dashboard<T>>
    with TickerProviderStateMixin, _DashboardHost<T, Dashboard<T>> {
  ///
  @override
  void initState() {
    super.initState();
    _initHost();
  }

  @override
  void dispose() {
    _disposeHost();
    super.dispose();
  }

  GlobalKey myWidgetKey = GlobalKey();

  bool get hasDimensions {
    final RenderBox? renderBox =
        myWidgetKey.currentContext?.findRenderObject() as RenderBox?;
    // Checks if the renderBox is not null and has a non-zero size
    return renderBox != null && renderBox.hasSize;
  }

  ///
  ViewportOffset? _offset;

  ///
  ViewportOffset get offset => _offset!;

  ///
  void _setNewOffset(ViewportOffset o, BoxConstraints constraints,
      [bool i = true]) {
    final h = _configure(o, constraints);

    _offset = o;

    if (i) {
      offset.applyViewportDimension(
          _layoutController._viewportDelegate.constraints.maxHeight);
    }

    if (!i) {
      offset.applyContentDimensions(
          0, _layoutController._ceilingScrollExtent ?? double.maxFinite);
      return;
    }

    var maxIndex = (_layoutController._endsTree.lastKey() ?? 0);

    var maxCoordinate = (_layoutController.getIndexCoordinate(maxIndex));

    _maxExtend = ((maxCoordinate[1] + 1) * _layoutController.verticalSlotEdge);

    _maxExtend -= constraints.maxHeight;

    if (_maxExtend < 0) {
      _maxExtend = widget.padding.vertical - _maxExtend.abs();
    } else {
      _maxExtend += widget.padding.vertical;
    }

    var maxExtent = _maxExtend.clamp(0.0, double.maxFinite);

    // While an item moves on a grid that scrolls in edit mode, one more row:
    // an item dragged to the bottom edge auto-scrolls there, and dropping it
    // on that row grows the grid. In the range itself, not only in the
    // auto-scroll's clamp — a rebuild during the drag would otherwise correct
    // `pixels` back out of it below. The drop rebuilds without the row.
    if (_moving && widget.editModeSettings.scrollWhileEditing) {
      maxExtent += _layoutController.verticalSlotEdge;
    }

    // A row ceiling ends the content at its last row, the drag row included.
    final ceiling = _layoutController._ceilingScrollExtent;
    if (ceiling != null) {
      maxExtent = min(maxExtent, ceiling);
      _maxExtend = min(_maxExtend, ceiling);
    }

    // Layout-time correction: `jumpTo` here re-entered the scroll machinery
    // (on a nested position it moved the band and started a ballistic
    // simulation inside layout). `correctBy` is the API made for this moment;
    // the `applyContentDimensions` below then publishes the new range.
    if (offset.hasPixels && offset.pixels > maxExtent && maxExtent > 0) {
      offset.correctBy(maxExtent - offset.pixels);
      // `correctBy` notifies no one, and the items position themselves with
      // their own `AnimatedBuilder` over this offset. A CONTENT change rebuilds
      // the stack's item list anyway, so they follow; a VIEWPORT size change
      // with an unchanged key set handed the stack its cached list, and the
      // items stayed at the old offset — an empty strip the size of the growth
      // at the bottom until the next scroll event (measured, consumer wave KB
      // phase B, anomaly A3; `T-KB2-07/08`).
      //
      // Two halves. (1) The stack is rebuilt right after this call by the
      // viewport builder, in the same frame; dropping its cached item list
      // makes that build place every item at the corrected offset — this
      // frame, without notifying anybody (`itemBuilder` is not called: the
      // built children stay in `_widgetsMap`). (2) The controller's listeners
      // are told once the frame is over, as `jumpTo` used to tell them: never
      // inside layout (that is what `jumpTo` did, and on a nested position it
      // also moved the band and started a ballistic simulation), and never
      // `jumpTo` itself, which would re-enter the scroll machinery. A
      // post-frame notification ALONE was measured too: the items are right
      // only one frame later, the first frame still shows the strip.
      _stateKey.currentState?._cachedStaticWidgets = null;
      final corrected = offset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && corrected is ScrollPosition && corrected.hasPixels) {
          corrected.notifyListeners();
        }
      });
    }

    try {
      offset.applyContentDimensions(0, maxExtent);
    } catch (e) {
      // Ignoruj błąd gdy wymiary się zmieniają podczas scrollowania
      debugPrint('Warning: applyContentDimensions error (ignored): $e');
    }

    _reportGridDimensions(h);
  }

  ///
  late double _maxExtend;

  bool scrollable = true;

  @override
  Widget build(BuildContext context) {
    _building = true;
    _reloadOnSlotCountChange(() => offset);

    return LayoutBuilder(builder: (context, constrains) {
      Unbounded.check(Axis.vertical, constrains);
      final placeholder = _placeholder();
      if (placeholder != null) {
        return placeholder;
      }

      return dashboardWidget(constrains);
    });
  }

  /// Whether the previous build handed `Scrollable` a physics that drags.
  bool? _lastCanDrag;

  Widget dashboardWidget(BoxConstraints constrains) {
    // W trybie edycji całkowicie wyłącz scrollowanie żeby resize działał
    //
    // Except with `scrollWhileEditing`: the stack's recognizer then enters the
    // arena only for a pointer on an item, and wins it before the drag of the
    // `Scrollable` could, so the physics may stay scrollable for the whole
    // session — also during a drag, because switching it mid-gesture is what
    // the `_lastCanDrag` workaround below exists for.
    final isEditing = widget.dashboardItemController.isEditing;
    final effectivePhysics = widget.editModeSettings.scrollWhileEditing
        ? widget.physics
        : isEditing
            ? const NeverScrollableScrollPhysics()
            : (scrollable
                ? widget.physics
                : const NeverScrollableScrollPhysics());

    // No key that depends on [isEditing]. A key swap remounted the
    // `Scrollable`, and the fresh `ScrollPosition` started at 0 — toggling edit
    // mode threw the user back to the top of a scrolled grid. `Scrollable`
    // handles a physics change in `didUpdateWidget`: a different physics type
    // rebuilds the position FROM the old one (`absorb`), which keeps `pixels`.
    //
    // One catch, and it is why the key existed. This grid applies its scroll
    // dimensions from `viewportBuilder`, i.e. INSIDE `Scrollable.build`, so the
    // new position's `setCanDrag` runs after `build` has already captured the
    // old gesture recognizers — the drag recognizer of the scrollable physics
    // survives into edit mode and a drag scrolls the pinned grid. One more
    // build after the frame hands the `RawGestureDetector` the recognizers
    // `setCanDrag` left behind.
    final canDrag = effectivePhysics is! NeverScrollableScrollPhysics;
    if (_lastCanDrag != null && _lastCanDrag != canDrag) {
      _setOnNextFrame();
    }
    _lastCanDrag = canDrag;

    return Scrollable(
        physics: effectivePhysics,
        controller: widget.scrollController ??
            (widget.primary ? PrimaryScrollController.maybeOf(context) : null),
        semanticChildCount: widget.dashboardItemController._items.length,
        dragStartBehavior: widget.dragStartBehavior ?? DragStartBehavior.start,
        scrollBehavior: widget.scrollBehavior,
        viewportBuilder: (c, o) {
          _layoutController._viewportOffset = o;
          if (!_reloading) _setNewOffset(o, constrains);
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            _stateKey.currentState?._listenOffset(o);
          });
          _building = false;
          return _buildStack(
            offset: offset,
            maxScrollOffset: _maxExtend,
            shouldCalculateNewDimensions: () {
              if (_moving) {
                return;
              }
              _setNewOffset(o, constrains);
            },
            onScrollStateChange: (st) {
              // Natychmiastowa zmiana scrollable żeby zablokować scroll podczas edycji
              if (scrollable != st) {
                setState(() {
                  scrollable = st;
                  _moving = !st;
                });
              }

              SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                if (!_moving) {
                  return;
                }
                _setNewOffset(o, constrains, _moving);
              });
            },
          );
        });
  }
}

class _ItemCurrentPositionTween extends Tween<_ItemCurrentPosition> {
  _ItemCurrentPositionTween(
      {required _ItemCurrentPosition begin,
      required _ItemCurrentPosition end,
      required this.onlyDimensions})
      : super(begin: begin, end: end);

  bool onlyDimensions;

  @override
  _ItemCurrentPosition lerp(double t) {
    return _ItemCurrentPosition(
        width: begin!.width * (1.0 - t) + end!.width * t,
        height: begin!.height * (1.0 - t) + end!.height * t,
        x: onlyDimensions ? end!.x : begin!.x * (1.0 - t) + end!.x * t,
        y: onlyDimensions ? end!.y : begin!.y * (1.0 - t) + end!.y * t);
  }
}
