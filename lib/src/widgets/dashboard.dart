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
class Dashboard<T extends DashboardItem> extends StatefulWidget {
  /// A list of widget arranged with hand or initially.
  Dashboard({super.key,
    required this.itemBuilder,
    required this.dashboardItemController,
    this.slotCount = 8,
    this.scrollController,
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
    this.slotBackgroundBuilder})
      : assert((slotHeight == null && slotAspectRatio == null) ||
      !(slotHeight != null && slotAspectRatio != null)),
        editModeSettings = editModeSettings ?? EditModeSettings();

  /// If [slotBackgroundBuilder] is not null, the background of the slots
  /// is drawn with the  [SlotBackgroundBuilder.build] method.
  ///
  /// The [SlotBackgroundBuilder.build] method is called for each slot that
  /// is visible on the screen and in the cache area.
  final SlotBackgroundBuilder<T>? slotBackgroundBuilder;

  /// If [scrollToAdded] is true, when a new item is added, the viewport
  /// scrolls to the added item.
  final bool scrollToAdded;

  /// [slotAspectRatio] determines slots height. Slot width determined by
  /// viewport width and [slotCount].
  final double? slotAspectRatio;

  /// [slotHeight] determines slots height by fixed length.
  final double? slotHeight;

  /// In edit mode, item position changes due to resizing/moving are animated.
  ///
  /// Also, changes due to slotCount changes are animated in edit mode.
  ///
  /// If [animateEverytime] item positions change with animation on
  /// slotCount changes. Else the changes are not animated.
  final bool animateEverytime;

  /// Absorb item gestures on edit mode.
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
  final double cacheExtend;

  /// When in Layout edit mode is true, some paintings/drawings are made on the
  /// viewport background and items (widgets) foreground.
  ///
  /// [editModeSettings] are used for settings related to the drawing, painting
  /// and animations during editing.
  ///
  /// For more information about settings see [EditModeSettings].
  final EditModeSettings editModeSettings;

  /// If the [dashboardItemController] uses a [DashboardItemStorageDelegate],
  /// the loading of the items initially is done with a FutureOr function.
  ///
  /// If the function returns a Future, this loading may take a while.
  /// In during loading, [Dashboard] shows [loadingPlaceholder].
  ///
  /// Default [loadingPlaceholder] is a centered circular process indicator.
  final Widget? loadingPlaceholder;

  /// If the function don't have any data then it should display something
  /// In empty data, [Dashboard] shows [emptyPlaceholder].
  ///
  /// Default [emptyPlaceholder] is a sizedBox means just empty space.
  final Widget? emptyPlaceholder;

  /// If the [dashboardItemController] uses a [DashboardItemStorageDelegate],
  /// the loading of the items initially is done with a FutureOr function.
  ///
  /// If the function throws a exception [Dashboard] will call
  /// [errorPlaceholder] and shows returned widget.
  final Widget Function(Object error, StackTrace stackTrace)? errorPlaceholder;

  /// [dashboardItemController] is dashboard items controller.
  /// The controller determines initial [DashboardItem]s and add / delete
  /// operations are done with this controller.
  ///
  /// Also storage operations are made with the [DashboardItemStorageDelegate]
  /// of the controller (if non-null).
  final DashboardItemController<T> dashboardItemController;

  /// Vertical slot count.
  final int slotCount;

  /// [Scrollable] widget scrollController.
  final ScrollController? scrollController;

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
  final double horizontalSpace;

  /// Vertical gap between two items.
  ///
  /// If the items startY equal 0 or items endY is biggest Y in the Dashboard,
  /// the gap is not placed. (Edges touching the edges of
  /// viewport excluding padding.)
  final double verticalSpace;

  /// [padding] is the spacing between items and Dashboard outer edges.
  final EdgeInsetsGeometry padding;

  /// When adding a new item, item dimensions editing or in the initial
  /// re-arranging, items trying to place certain position. When the item not
  /// fit to the position (e.g. conflict with another item), if [shrinkToPlace]
  /// is true item dimensions trying to shrink, else Dashboard decide that item
  /// not placed to the position.
  ///
  /// Shrinking pays attention minWidth / minHeight.
  final bool shrinkToPlace;

  /// Initially try slide items to top.
  ///
  /// If [slideToTop] is true, Initially empty slots at the top are tried
  /// to be filled with items that starting from the top.
  final bool slideToTop;

  /// [padding] resolved with [textDirection].
  final TextDirection textDirection;

  /// Each item is wrapped by a [Material]. Material's parameters can be
  /// specified with [itemStyle].
  ///
  /// Look [Material] documentation for more.
  final ItemStyle itemStyle;

  @override
  State<Dashboard<T>> createState() => _DashboardState<T>();
}

class _DashboardState<T extends DashboardItem> extends State<Dashboard<T>>
    with TickerProviderStateMixin {
  ///
  @override
  void initState() {
    _layoutController = _DashboardLayoutController<T>();
    
    // Initialize responsive properties with widget defaults
    _currentSlotCount = widget.slotCount;
    _currentVerticalSpace = widget.verticalSpace;
    _currentHorizontalSpace = widget.horizontalSpace;
    _currentPadding = widget.padding;
    _initialSlotCountLoaded = _currentSlotCount; // Track for initial load

    // Explicitly set slotCount in the controller
    _layoutController.slotCount = _currentSlotCount; 

    _layoutController.addListener(() {
      setState(() {});
    });

    widget.dashboardItemController._attach(_layoutController);
    if (_withDelegate) {
      // widget.dashboardItemController._asyncSnap =
      //     ValueNotifier(const AsyncSnapshot.waiting());
      widget.dashboardItemController._loadItems(_currentSlotCount); // Use initial _currentSlotCount
      widget.dashboardItemController._asyncSnap!.addListener(() {
        if (mounted) {
          if (!_building) {
            setState(() {});
          }
        }
      });
    }
    super.initState();
  }

  GlobalKey myWidgetKey = GlobalKey();

  bool get hasDimensions {
    final RenderBox? renderBox =
    myWidgetKey.currentContext?.findRenderObject() as RenderBox?;
    // Checks if the renderBox is not null and has a non-zero size
    return renderBox != null && renderBox.hasSize;
  }

  bool _building = true;

  AsyncSnapshot? get _snap => widget.dashboardItemController._asyncSnap?.value;

  bool get _withDelegate =>
      widget.dashboardItemController.itemStorageDelegate != null;

  ///
  late _DashboardLayoutController<T> _layoutController;

  ///
  ViewportOffset? _offset;

  ///
  ViewportOffset get offset => _offset!;

  bool _reloading = false;

  // Responsive properties initialized in initState
  late int _currentSlotCount;
  late double _currentVerticalSpace;
  late double _currentHorizontalSpace;
  late EdgeInsetsGeometry _currentPadding;
  
  // To track if the slot count used for initial item load changes due to immediate responsive calculation
  late int _initialSlotCountLoaded;


  void _setOnNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  ///
  _setNewOffset(ViewportOffset o, BoxConstraints constraints, [bool i = true]) {
    /// check slot count
    /// check new constrains equal exists
    _layoutController.absorbPointer = widget.absorbPointer;
    // Use _current* responsive values
    _layoutController._viewportDelegate = _ViewportDelegate(
        constraints: constraints,
        padding: _currentPadding.resolve(widget.textDirection),
        mainAxisSpace: _currentHorizontalSpace,
        crossAxisSpace: _currentVerticalSpace);

    // Use _currentSlotCount for attaching and checking
    if (_layoutController._isAttached &&
        (_layoutController.slotCount != _currentSlotCount ||
            _layoutController.slideToTop != widget.slideToTop ||
            _layoutController.shrinkToPlace != widget.shrinkToPlace) &&
        !_reloading) {
      _layoutController.attach(
          viewportOffset: o,
          shrinkOnMove: widget.editModeSettings.shrinkOnMove,
          animateEverytime: widget.animateEverytime,
          slideToTop: widget.slideToTop,
          shrinkToPlace: widget.shrinkToPlace,
          axis: Axis.vertical,
          itemController: widget.dashboardItemController,
          slotCount: _currentSlotCount, // Use _currentSlotCount
          scrollToAdded: widget.scrollToAdded);
      _setOnNextFrame();
    }

    if (!_layoutController._isAttached) {
      _layoutController.attach(
          viewportOffset: o,
          shrinkOnMove: widget.editModeSettings.shrinkOnMove,
          animateEverytime: widget.animateEverytime,
          slideToTop: widget.slideToTop,
          shrinkToPlace: widget.shrinkToPlace,
          axis: Axis.vertical,
          itemController: widget.dashboardItemController,
          slotCount: _currentSlotCount, // Use _currentSlotCount
          scrollToAdded: widget.scrollToAdded);
      _setOnNextFrame();
    }

    double h;

    // Use _currentSlotCount for slot height calculation
    if (widget.slotHeight != null) {
      h = widget.slotHeight!;
    } else if (widget.slotAspectRatio != null) {
      h = _layoutController._viewportDelegate.resolvedConstrains.maxWidth /
          _currentSlotCount /
          widget.slotAspectRatio!;
    } else {
      h = _layoutController._viewportDelegate.resolvedConstrains.maxWidth /
          _currentSlotCount;
    }

    _layoutController._setSizes(
        _layoutController._viewportDelegate.resolvedConstrains, h);

    _offset = o;

    if (i) {
      offset.applyViewportDimension(
          _layoutController._viewportDelegate.constraints.maxHeight);
    }

    if (!i) {
      offset.applyContentDimensions(0, double.maxFinite);
      return;
    }

    var maxIndex = (_layoutController._endsTree.lastKey() ?? 0);

    var maxCoordinate = (_layoutController.getIndexCoordinate(maxIndex));

    _maxExtend = ((maxCoordinate[1] + 1) * _layoutController.verticalSlotEdge);

    _maxExtend -= constraints.maxHeight;

    // Use _currentPadding for maxExtend calculation
    final resolvedPadding = _currentPadding.resolve(widget.textDirection);
    if (_maxExtend < 0) {
      _maxExtend = resolvedPadding.vertical - _maxExtend.abs();
    } else {
      _maxExtend += resolvedPadding.vertical;
    }

    if (_maxExtend > 0) {
      offset.applyContentDimensions(0, _maxExtend.clamp(0, double.maxFinite));
    }
  }

  ///
  late double _maxExtend;

  ///
  final GlobalKey<_DashboardStackState<T>> _stateKey =
  GlobalKey<_DashboardStackState<T>>();

  final GlobalKey<ScrollableState> _scrollableKey =
  GlobalKey<ScrollableState>();

  bool scrollable = true;

  int? _reloadFor;

  @override
  Widget build(BuildContext context) {
    _building = true;

    return LayoutBuilder(builder: (context, constrains) {
      Unbounded.check(Axis.vertical, constrains);

      final screenWidth = constrains.maxWidth;
      
      // Determine responsive values
      int newResponsiveSlotCount = widget.slotCount;
      double newResponsiveVerticalSpace = widget.verticalSpace;
      double newResponsiveHorizontalSpace = widget.horizontalSpace;
      EdgeInsetsGeometry newResponsivePadding = widget.padding;

      if (screenWidth < 600) { // Small screens
        newResponsiveVerticalSpace = widget.verticalSpace + 8;
        newResponsiveHorizontalSpace = widget.horizontalSpace + 8;
        if (widget.padding is EdgeInsets) {
          newResponsivePadding = (widget.padding as EdgeInsets).add(const EdgeInsets.all(8));
        }
        newResponsiveSlotCount = 4;
      } else if (screenWidth < 900) { // Medium screens
        newResponsiveVerticalSpace = widget.verticalSpace + 4;
        newResponsiveHorizontalSpace = widget.horizontalSpace + 4;
        if (widget.padding is EdgeInsets) {
          newResponsivePadding = (widget.padding as EdgeInsets).add(const EdgeInsets.all(4));
        }
        newResponsiveSlotCount = 6;
      }
      // For large screens (> 900), defaults from widget are used (already set as initial values for newResponsive*)

      // If slot count changed due to responsiveness, schedule a setState to rebuild and trigger item reload if necessary.
      // Also update if other responsive values changed to ensure the UI reflects them.
      if (_currentSlotCount != newResponsiveSlotCount ||
          _currentVerticalSpace != newResponsiveVerticalSpace ||
          _currentHorizontalSpace != newResponsiveHorizontalSpace ||
          _currentPadding != newResponsivePadding) {
        
        // Check if this is the very first build pass after initState where _initialSlotCountLoaded was set.
        // If newResponsiveSlotCount is different from what was loaded in initState, we need to reload items.
        bool needsImmediateReloadForInitial = (_initialSlotCountLoaded != newResponsiveSlotCount && 
                                             _layoutController.slotCount == _initialSlotCountLoaded &&
                                             widget.dashboardItemController.itemStorageDelegate!.layoutsBySlotCount);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // Update all current responsive values
              _currentSlotCount = newResponsiveSlotCount;
              _currentVerticalSpace = newResponsiveVerticalSpace;
              _currentHorizontalSpace = newResponsiveHorizontalSpace;
              _currentPadding = newResponsivePadding;
              if (needsImmediateReloadForInitial) {
                _reloading = true; // Force reload state for the next build
                _reloadFor = _currentSlotCount;
              }
            });
          }
        });
      }
      
      // For the current build cycle, ensure we are using the new responsive values for layout.
      // This is important because _setNewOffset will be called within this build cycle.
      _currentSlotCount = newResponsiveSlotCount;
      _currentVerticalSpace = newResponsiveVerticalSpace;
      _currentHorizontalSpace = newResponsiveHorizontalSpace;
      _currentPadding = newResponsivePadding;

      // Item reload logic based on _currentSlotCount
      // This handles reloads if _currentSlotCount changes (e.g. after the setState via postFrameCallback,
      // or if needsImmediateReloadForInitial was true and setState also set _reloading=true)
      bool slotCountActuallyChanged = _layoutController.slotCount != _currentSlotCount;
      if (_layoutController._isAttached &&
          (!_reloading || (_reloading && _reloadFor != _currentSlotCount)) && // if reloading, ensure it's for the new slot count
          slotCountActuallyChanged &&
          _withDelegate &&
          widget.dashboardItemController.itemStorageDelegate!.layoutsBySlotCount) {
        _reloading = true;
        _reloadFor = _currentSlotCount;
        widget.dashboardItemController._items.clear();
        _layoutController._startsTree.clear();
        _layoutController._indexesTree.clear();
        _layoutController._endsTree.clear();
        // _loadItems will use the _currentSlotCount passed to attach.
        // No, _loadItems needs to be called explicitly here.
         var loader = widget.dashboardItemController._loadItems(_currentSlotCount);
        if (loader is Future) {
          loader.then((value) {
            if (_reloadFor == _currentSlotCount && mounted) {
               _reloading = false;
              // Re-attach with new slot count to finalize layout
              // This might be redundant if _setNewOffset handles it, but good for explicit reload.
               _layoutController.attach(
                  viewportOffset: offset, // offset might be null initially if not set.
                  shrinkOnMove: widget.editModeSettings.shrinkOnMove,
                  animateEverytime: widget.animateEverytime,
                  slideToTop: widget.slideToTop,
                  shrinkToPlace: widget.shrinkToPlace,
                  axis: Axis.vertical,
                  itemController: widget.dashboardItemController,
                  slotCount: _currentSlotCount,
                  scrollToAdded: widget.scrollToAdded);
              if(mounted) setState(() {}); // Ensure UI updates after async load + attach
            }
          });
        } else { // Loader is not a future
           if (_reloadFor == _currentSlotCount && mounted) {
            _reloading = false;
            _layoutController.attach(
                  viewportOffset: offset,
                  shrinkOnMove: widget.editModeSettings.shrinkOnMove,
                  animateEverytime: widget.animateEverytime,
                  slideToTop: widget.slideToTop,
                  shrinkToPlace: widget.shrinkToPlace,
                  axis: Axis.vertical,
                  itemController: widget.dashboardItemController,
                  slotCount: _currentSlotCount,
                  scrollToAdded: widget.scrollToAdded);
            // No setState needed here as it's synchronous
           }
        }
      } else if (_reloading && _reloadFor == _currentSlotCount && slotCountActuallyChanged) {
        // If we were reloading for the current slot count, but the controller's slot count is now aligned,
        // then the reload process (including attach) should have completed.
        // So, we can turn off reloading.
        // This case might be hit if loadItems was synchronous.
        _reloading = false;
      }


      if (_withDelegate) {
        if (_snap!.connectionState == ConnectionState.none) {
          _building = false;
          return widget.errorPlaceholder
              ?.call(_snap!.error!, _snap!.stackTrace!) ??
              const SizedBox();
        } else if (_snap!.connectionState == ConnectionState.waiting || _reloading) { // Check _reloading here
          _building = false;
          return widget.loadingPlaceholder ??
              const Center(
                child: CircularProgressIndicator(),
              );
        }
      }
      // dashboardWidget now uses the _current* values that are set based on constrains
      return dashboardWidget(constrains);
    });
  }

  bool _moving = false;

  // This function now primarily builds the Scrollable and _DashboardStack,
  // using the _current* properties that have been updated by the LayoutBuilder in build().
  Widget dashboardWidget(BoxConstraints constrains) {
    return Scrollable(
        physics:
        scrollable ? widget.physics : const NeverScrollableScrollPhysics(),
        key: _scrollableKey,
        controller: widget.scrollController,
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
          return _DashboardStack<T>(
            itemStyle: widget.itemStyle,
            shouldCalculateNewDimensions: () {
              if (_moving) {
                return;
              }
              _setNewOffset(o, constrains);
            },
            onScrollStateChange: (st) {

              SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                _moving = !st;

                setState(() {
                  scrollable = st;
                });

                if (!_moving) {
                  return;
                }
                _setNewOffset(o, constrains, _moving);
              });
            },
            emptyPlaceholder: widget.emptyPlaceholder,
            maxScrollOffset: _maxExtend,
            editModeSettings: widget.editModeSettings,
            cacheExtend: widget.cacheExtend,
            key: _stateKey,
            itemBuilder: widget.itemBuilder,
            dashboardController: _layoutController,
            offset: offset,
            slotBackground: widget.slotBackgroundBuilder,
          );
        });
  }
}

class _ItemCurrentPositionTween extends Tween<_ItemCurrentPosition> {
  _ItemCurrentPositionTween({required _ItemCurrentPosition begin,
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
