part of '../dashboard_base.dart';

/// What [Dashboard] and [SliverDashboard] are both configured with.
///
/// The two widgets declare the same fields; this is the view of them the
/// shared state code ([_DashboardHost]) reads, so neither widget has to
/// extend the other.
abstract interface class _DashboardConfig<T extends DashboardItem> {
  DashboardItemController<T> get dashboardItemController;
  DashboardItemBuilder<T> get itemBuilder;
  int get slotCount;
  double get cacheExtend;
  double get verticalSpace;
  double get horizontalSpace;
  EdgeInsetsGeometry get padding;
  bool get shrinkToPlace;
  bool get slideToTop;
  double? get slotAspectRatio;
  double? get slotHeight;
  EditModeSettings get editModeSettings;
  TextDirection get textDirection;
  Widget Function(Object error, StackTrace stackTrace)? get errorPlaceholder;
  Widget? get loadingPlaceholder;
  Widget? get emptyPlaceholder;
  bool get absorbPointer;
  bool get animateEverytime;
  ItemStyle get itemStyle;
  bool get scrollToAdded;
  SlotBackgroundBuilder<T>? get slotBackgroundBuilder;
  void Function(GridDimensions dimensions)? get onGridDimensionsChanged;
  VirtualColumnsConfig? get virtualColumnsConfig;
}

/// The state both grids share: the layout controller and its listeners, the
/// items of a storage delegate, the reload on another slot count, the slot
/// geometry and the stack. What differs is only how the grid scrolls — a
/// `Scrollable` of its own ([Dashboard]) or the enclosing one
/// ([SliverDashboard]).
mixin _DashboardHost<T extends DashboardItem, W extends StatefulWidget>
    on State<W> {
  _DashboardConfig<T> get config => widget as _DashboardConfig<T>;

  ///
  late _DashboardLayoutController<T> _layoutController;

  VoidCallback? _layoutListener;
  VoidCallback? _asyncSnapListener;
  VoidCallback? _editingListener;

  bool _building = true;
  bool _reloading = false;
  int? _reloadFor;

  /// Whether an item is being moved or resized.
  bool _moving = false;

  ///
  final GlobalKey<_DashboardStackState<T>> _stateKey =
      GlobalKey<_DashboardStackState<T>>();

  AsyncSnapshot? get _snap => config.dashboardItemController._asyncSnap?.value;

  bool get _withDelegate =>
      config.dashboardItemController.itemStorageDelegate != null;

  void _initHost() {
    _layoutController = _DashboardLayoutController<T>();
    _layoutListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _layoutController.addListener(_layoutListener!);

    config.dashboardItemController._attach(_layoutController);

    // Listener na zmianę trybu edycji żeby od razu blokować/odblokować scroll
    _editingListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    // Nasłuchuj na _layoutController bo to tam jest notifyListeners()
    _layoutController.addListener(_editingListener!);

    if (_withDelegate) {
      config.dashboardItemController._loadItems(config.slotCount);
      _asyncSnapListener = () {
        if (mounted) {
          // Use addPostFrameCallback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_building) {
              setState(() {});
            }
          });
        }
      };
      config.dashboardItemController._asyncSnap!
          .addListener(_asyncSnapListener!);
    }
  }

  void _disposeHost() {
    if (_layoutListener != null) {
      _layoutController.removeListener(_layoutListener!);
    }
    if (_asyncSnapListener != null) {
      config.dashboardItemController._asyncSnap
          ?.removeListener(_asyncSnapListener!);
    }
    if (_editingListener != null) {
      _layoutController.removeListener(_editingListener!);
    }
    config.dashboardItemController._detach(_layoutController);
  }

  void _setOnNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _attachLayout(ViewportOffset o) {
    _layoutController.attach(
        viewportOffset: o,
        shrinkOnMove: config.editModeSettings.shrinkOnMove,
        animateEverytime: config.animateEverytime,
        slideToTop: config.slideToTop,
        shrinkToPlace: config.shrinkToPlace,
        axis: Axis.vertical,
        itemController: config.dashboardItemController,
        slotCount: config.slotCount,
        scrollToAdded: config.scrollToAdded,
        virtualColumnsConfig: config.virtualColumnsConfig);
  }

  /// Attaches the layout controller to [o] when it is not yet, or re-attaches
  /// it when a layout parameter changed, and sets the slot geometry for a grid
  /// laid out in [constraints]. Returns the slot height.
  double _configure(ViewportOffset o, BoxConstraints constraints) {
    /// check slot count
    /// check new constrains equal exists
    _layoutController.absorbPointer = config.absorbPointer;
    _layoutController._viewportDelegate = _ViewportDelegate(
        constraints: constraints,
        padding: config.padding.resolve(config.textDirection),
        // The grid scrolls vertically: its main axis is vertical, so the gap
        // between rows is the VERTICAL space. These were crossed, and each
        // parameter spaced the other direction.
        mainAxisSpace: config.verticalSpace,
        crossAxisSpace: config.horizontalSpace);

    if (_layoutController._isAttached &&
        (_layoutController.slotCount != config.slotCount ||
            _layoutController.slideToTop != config.slideToTop ||
            _layoutController.shrinkToPlace != config.shrinkToPlace) &&
        !_reloading) {
      _attachLayout(o);
      _setOnNextFrame();
    }

    if (!_layoutController._isAttached) {
      _attachLayout(o);
      _setOnNextFrame();
    }

    double h;

    if (config.slotHeight != null) {
      h = config.slotHeight!;
    } else if (config.slotAspectRatio != null) {
      h = _layoutController._viewportDelegate.resolvedConstrains.maxWidth /
          config.slotCount /
          config.slotAspectRatio!;
    } else {
      h = _layoutController._viewportDelegate.resolvedConstrains.maxWidth /
          config.slotCount;
    }

    _layoutController._setSizes(
        _layoutController._viewportDelegate.resolvedConstrains, h);
    return h;
  }

  /// Tells [_DashboardConfig.onGridDimensionsChanged] the geometry
  /// [_configure] set, with slot height [h].
  void _reportGridDimensions(double h) {
    // Oblicz wymiary grida
    final gridDimensions = GridDimensions(
      // The width items are laid out with (`_setSizes`). Not width / slotCount:
      // with virtual columns that averages the narrow disabled columns in.
      slotWidth: _layoutController.slotEdge,
      slotHeight: h,
      columns: config.slotCount,
      totalWidth:
          _layoutController._viewportDelegate.resolvedConstrains.maxWidth,
      totalHeight:
          _layoutController._viewportDelegate.resolvedConstrains.maxHeight,
      padding: config.padding.resolve(config.textDirection),
      horizontalSpace: config.horizontalSpace,
      verticalSpace: config.verticalSpace,
    );

    // Wywołaj callback
    config.onGridDimensionsChanged?.call(gridDimensions);
  }

  /// Reloads the items from the storage delegate when the slot count changed
  /// and the delegate keeps a layout per slot count; [offset] is what the
  /// controller is attached to once they are in.
  void _reloadOnSlotCountChange(ViewportOffset Function() offset) {
    bool differentReload = _reloadFor != config.slotCount;
    if (_layoutController._isAttached &&
        (!_reloading || differentReload) &&
        _layoutController.slotCount != config.slotCount &&
        _withDelegate &&
        config
            .dashboardItemController.itemStorageDelegate!.layoutsBySlotCount) {
      _reloading = true;
      _reloadFor = config.slotCount;
      config.dashboardItemController._items.clear();
      _layoutController._startsTree.clear();
      _layoutController._slotIndex.clear();
      _layoutController._endsTree.clear();
      var loader = config.dashboardItemController._loadItems(config.slotCount);

      if (loader is Future) {
        loader.then((value) {
          if (_reloadFor == config.slotCount) {
            _reloading = false;
            _attachLayout(offset());
          }
        });
      } else {
        if (_reloadFor == config.slotCount) {
          _reloading = false;
          _attachLayout(offset());
        }
      }
    }
  }

  /// The loading or error placeholder while the items of a storage delegate
  /// are not there, or `null` once they are.
  Widget? _placeholder() {
    if (!_withDelegate) {
      return null;
    }
    // A controller swapped in under the same key never ran `_loadItems`
    // (that happens in `initState`), so it has no snapshot yet.
    if (_snap == null) {
      _building = false;
      return config.loadingPlaceholder ??
          const Center(
            child: CircularProgressIndicator(),
          );
    }
    if (_snap!.connectionState == ConnectionState.none) {
      _building = false;
      return config.errorPlaceholder?.call(_snap!.error!, _snap!.stackTrace!) ??
          const SizedBox();
    } else if (_snap!.connectionState == ConnectionState.waiting ||
        _reloading) {
      _building = false;

      return config.loadingPlaceholder ??
          const Center(
            child: CircularProgressIndicator(),
          );
    }
    return null;
  }

  _DashboardStack<T> _buildStack({
    required ViewportOffset offset,
    required double maxScrollOffset,
    required void Function() shouldCalculateNewDimensions,
    required void Function(bool scrollable) onScrollStateChange,
    bool sliver = false,
  }) {
    return _DashboardStack<T>(
      itemStyle: config.itemStyle,
      shouldCalculateNewDimensions: shouldCalculateNewDimensions,
      onScrollStateChange: onScrollStateChange,
      emptyPlaceholder: config.emptyPlaceholder,
      maxScrollOffset: maxScrollOffset,
      editModeSettings: config.editModeSettings,
      cacheExtend: config.cacheExtend,
      key: _stateKey,
      itemBuilder: config.itemBuilder,
      dashboardController: _layoutController,
      offset: offset,
      slotBackground: config.slotBackgroundBuilder,
      sliver: sliver,
    );
  }
}
