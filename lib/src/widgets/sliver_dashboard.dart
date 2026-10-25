part of '../dashboard_base.dart';

/// A [Dashboard] as a sliver, for a `CustomScrollView` it scrolls with —
/// under a `SliverAppBar`, a band, a refresh indicator, other slivers.
///
/// It takes the parameters of [Dashboard] except the ones of its own
/// `Scrollable` (`scrollController`, `primary`, `physics`, `dragStartBehavior`,
/// `scrollBehavior`): the enclosing scroll view owns those. Everything else
/// behaves as in [Dashboard], virtualisation included: only the rows on screen
/// and within [cacheExtend] of it are built.
///
/// The grid is at least one viewport tall, as a [Dashboard] always fills its
/// viewport, so an empty or short grid still has empty slots to drop on in
/// edit mode.
///
/// In edit mode the gestures are always the ones of
/// [EditModeSettings.scrollWhileEditing]: the drag of the enclosing scroll view
/// would win over the edit pan, so a drag on an empty slot scrolls, a finger
/// picks an item up after [EditModeSettings.touchPickUpDelay], and an item at
/// the top or bottom edge scrolls the whole scroll view — the band above the
/// grid collapses or expands first.
///
/// In a [MobileDashboardWrapper], build it from
/// [MobileDashboardWrapper.scrollViewBuilder]: the carousel then moves the
/// grid sideways inside the sliver and the slivers around it stay in place.
class SliverDashboard<T extends DashboardItem> extends StatefulWidget
    implements _DashboardConfig<T> {
  /// A sliver grid; see [Dashboard] for the parameters.
  SliverDashboard(
      {super.key,
      required this.itemBuilder,
      required this.dashboardItemController,
      this.slotCount = 8,
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
      this.virtualColumnsConfig})
      : assert((slotHeight == null && slotAspectRatio == null) ||
            !(slotHeight != null && slotAspectRatio != null)),
        editModeSettings = editModeSettings ?? EditModeSettings();

  /// See [Dashboard.itemBuilder].
  @override
  final DashboardItemBuilder<T> itemBuilder;

  /// See [Dashboard.dashboardItemController].
  @override
  final DashboardItemController<T> dashboardItemController;

  /// See [Dashboard.slotCount].
  @override
  final int slotCount;

  /// See [Dashboard.cacheExtend].
  @override
  final double cacheExtend;

  /// See [Dashboard.verticalSpace].
  @override
  final double verticalSpace;

  /// See [Dashboard.horizontalSpace].
  @override
  final double horizontalSpace;

  /// See [Dashboard.padding].
  @override
  final EdgeInsetsGeometry padding;

  /// See [Dashboard.shrinkToPlace].
  @override
  final bool shrinkToPlace;

  /// See [Dashboard.slideToTop].
  @override
  final bool slideToTop;

  /// See [Dashboard.slotAspectRatio].
  @override
  final double? slotAspectRatio;

  /// See [Dashboard.slotHeight].
  @override
  final double? slotHeight;

  /// See [Dashboard.editModeSettings]. [EditModeSettings.scrollWhileEditing]
  /// is implied.
  @override
  final EditModeSettings editModeSettings;

  /// See [Dashboard.textDirection].
  @override
  final TextDirection textDirection;

  /// See [Dashboard.errorPlaceholder]. Fills the rest of the viewport.
  @override
  final Widget Function(Object error, StackTrace stackTrace)? errorPlaceholder;

  /// See [Dashboard.loadingPlaceholder]. Fills the rest of the viewport.
  @override
  final Widget? loadingPlaceholder;

  /// See [Dashboard.emptyPlaceholder].
  @override
  final Widget? emptyPlaceholder;

  /// See [Dashboard.absorbPointer].
  @override
  final bool absorbPointer;

  /// See [Dashboard.animateEverytime].
  @override
  final bool animateEverytime;

  /// See [Dashboard.itemStyle].
  @override
  final ItemStyle itemStyle;

  /// See [Dashboard.scrollToAdded]. Scrolls the enclosing scroll view.
  @override
  final bool scrollToAdded;

  /// See [Dashboard.slotBackgroundBuilder].
  @override
  final SlotBackgroundBuilder<T>? slotBackgroundBuilder;

  /// See [Dashboard.onGridDimensionsChanged].
  @override
  final void Function(GridDimensions dimensions)? onGridDimensionsChanged;

  /// See [Dashboard.virtualColumnsConfig].
  @override
  final VirtualColumnsConfig? virtualColumnsConfig;

  @override
  State<SliverDashboard<T>> createState() => _SliverDashboardState<T>();
}

class _SliverDashboardState<T extends DashboardItem>
    extends State<SliverDashboard<T>>
    with _DashboardHost<T, SliverDashboard<T>> {
  late final _SliverDashboardOffset _offset = _SliverDashboardOffset(context);

  /// The window the slot geometry was last set for; geometry is set again
  /// only when it changes or this state rebuilds, not on every scroll frame
  /// (each of which rebuilds the `SliverLayoutBuilder`).
  Size? _configuredFor;
  bool _needsConfigure = true;

  @override
  void initState() {
    super.initState();
    _initHost();
  }

  @override
  void dispose() {
    _disposeHost();
    _offset.dispose();
    super.dispose();
  }

  /// The extent of the content when the current move or resize started;
  /// `null` while no item moves.
  double? _contentAtMoveStart;

  /// The scroll extent of the grid: its rows and padding, and at least
  /// [window].
  ///
  /// While an item moves, the content as it was when the move started plus
  /// one row, where the item can be dragged to grow the grid — frozen, as the
  /// range of a [Dashboard] is: this is read on every scroll frame, and the
  /// dragged item itself is in the layout, so a live extent would grow with
  /// the item at the bottom edge for as long as it is held there.
  double _extent(double window) {
    final lastRow = _layoutController
        .getIndexCoordinate(_layoutController._endsTree.lastKey() ?? 0)[1];
    var content = (lastRow + 1) * _layoutController.verticalSlotEdge +
        config.padding.resolve(config.textDirection).vertical;
    if (_moving) {
      content = (_contentAtMoveStart ??= content) +
          _layoutController.verticalSlotEdge;
    } else {
      _contentAtMoveStart = null;
    }
    return max(content, window);
  }

  @override
  Widget build(BuildContext context) {
    _building = true;
    _needsConfigure = true;
    _reloadOnSlotCountChange(() => _offset);
    final carousel = _SliverCarouselScope.maybeOf(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stateKey.currentState?._listenOffset(_offset);
    });

    return SliverLayoutBuilder(builder: (context, constraints) {
      assert(constraints.axisDirection == AxisDirection.down,
          'SliverDashboard scrolls down only');
      final placeholder = _placeholder();
      if (placeholder != null) {
        return SliverFillRemaining(hasScrollBody: false, child: placeholder);
      }

      final window = Size(carousel?.gridWidth ?? constraints.crossAxisExtent,
          constraints.viewportMainAxisExtent);
      _layoutController._viewportOffset = _offset;
      if (!_reloading && (_needsConfigure || _configuredFor != window)) {
        _reportGridDimensions(
            _configure(_offset, BoxConstraints.tight(window)));
        _configuredFor = window;
        _needsConfigure = false;
      }
      _building = false;

      // Inside the layout callback: the stack and the item layer listen to
      // the offset, and as descendants of this builder they may be marked
      // dirty here and are rebuilt in the same pass.
      _offset._overlap = constraints.overlap;
      _offset._update(constraints.scrollOffset);

      final extent = _extent(window.height);
      return _SliverDashboardWindow(
        extent: extent,
        childWidth: window.width,
        horizontalOffset: carousel?.offset,
        child: _buildStack(
          offset: _offset,
          maxScrollOffset: extent - window.height,
          sliver: true,
          shouldCalculateNewDimensions: () {
            if (_moving) {
              return;
            }
            setState(() {});
          },
          onScrollStateChange: (st) {
            if (_moving == st) {
              setState(() {
                _moving = !st;
              });
            }
          },
        ),
      );
    });
  }
}

/// The scroll offset of a [SliverDashboard], as its stack sees it: `pixels`
/// is how far the grid is scrolled under the top of the viewport (the
/// sliver's `scrollOffset`), and every scroll the grid asks for — the
/// auto-scroll, scrolling to an added item — goes to the enclosing scroll
/// view.
class _SliverDashboardOffset extends ViewportOffset {
  _SliverDashboardOffset(this._context);

  final BuildContext _context;
  double _pixels = 0;

  /// How much of the top of the grid lies under pinned slivers before it
  /// (a pinned `SliverAppBar`), from the last layout.
  double _overlap = 0;

  ScrollPosition? get _position => Scrollable.maybeOf(_context)?.position;

  void _update(double pixels) {
    if (pixels != _pixels) {
      _pixels = pixels;
      notifyListeners();
    }
  }

  @override
  double get pixels => _pixels;

  @override
  bool get hasPixels => true;

  @override
  ScrollDirection get userScrollDirection =>
      _position?.userScrollDirection ?? ScrollDirection.idle;

  @override
  bool get allowImplicitScrolling => _position?.allowImplicitScrolling ?? false;

  @override
  bool applyViewportDimension(double viewportDimension) => true;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) =>
      true;

  @override
  void correctBy(double correction) {}

  @override
  void jumpTo(double pixels) {
    final position = _position;
    if (position != null && position.hasPixels) {
      position.jumpTo(position.pixels + pixels - _pixels);
    }
  }

  @override
  Future<void> animateTo(double to,
      {required Duration duration, required Curve curve}) {
    final position = _position;
    if (position != null && position.hasPixels) {
      return position.animateTo(position.pixels + to - _pixels,
          duration: duration, curve: curve);
    }
    return Future<void>.value();
  }

  /// Scrolls the enclosing scroll view by [delta], within its range, as a
  /// mouse wheel does.
  void scrollBy(double delta) {
    _position?.pointerScroll(delta);
  }
}

/// The sliver of a [SliverDashboard]: [extent] of scroll, and a box child —
/// the stack — that is as tall as the viewport and stays pinned to the
/// visible part of the sliver.
///
/// That is what keeps the stack the grid it is in a [Dashboard]: a box the
/// size of its viewport, with the content scrolled under it by `pixels`, so
/// virtualisation, the item layer, the edge zones and every drag correction
/// work as they do there. (Laying the stack out at the full content height
/// instead, as upstream's sliver does, builds every item.)
///
/// [childWidth] may be wider than the viewport: in a carousel the grid is
/// laid out at its full width and moved sideways by [horizontalOffset] when
/// painted and hit-tested, clipped to the viewport.
class _SliverDashboardWindow extends SingleChildRenderObjectWidget {
  const _SliverDashboardWindow({
    required this.extent,
    required this.childWidth,
    required this.horizontalOffset,
    required super.child,
  });

  final double extent;
  final double childWidth;
  final ValueListenable<double>? horizontalOffset;

  @override
  _RenderSliverDashboard createRenderObject(BuildContext context) =>
      _RenderSliverDashboard(
        extent: extent,
        childWidth: childWidth,
        horizontalOffset: horizontalOffset,
      );

  @override
  void updateRenderObject(
      BuildContext context, _RenderSliverDashboard renderObject) {
    renderObject
      ..extent = extent
      ..childWidth = childWidth
      ..horizontalOffset = horizontalOffset;
  }
}

class _RenderSliverDashboard extends RenderSliver
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderSliverDashboard({
    required double extent,
    required double childWidth,
    required ValueListenable<double>? horizontalOffset,
  })  : _extent = extent,
        _childWidth = childWidth,
        _horizontalOffset = horizontalOffset;

  double _extent;
  set extent(double value) {
    if (value != _extent) {
      _extent = value;
      markNeedsLayout();
    }
  }

  double _childWidth;
  set childWidth(double value) {
    if (value != _childWidth) {
      _childWidth = value;
      markNeedsLayout();
    }
  }

  ValueListenable<double>? _horizontalOffset;
  set horizontalOffset(ValueListenable<double>? value) {
    if (identical(value, _horizontalOffset)) return;
    if (attached) _horizontalOffset?.removeListener(markNeedsPaint);
    _horizontalOffset = value;
    if (attached) _horizontalOffset?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double get _dx => _horizontalOffset?.value ?? 0.0;

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _horizontalOffset?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _horizontalOffset?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverPhysicalParentData) {
      child.parentData = SliverPhysicalParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    child?.layout(BoxConstraints.tightFor(
        width: _childWidth, height: constraints.viewportMainAxisExtent));

    final paintExtent = calculatePaintOffset(constraints, from: 0, to: _extent);
    geometry = SliverGeometry(
      scrollExtent: _extent,
      paintExtent: paintExtent,
      cacheExtent: calculateCacheOffset(constraints, from: 0, to: _extent),
      maxPaintExtent: _extent,
      hitTestExtent: paintExtent,
      hasVisualOverflow: true,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || geometry!.paintExtent == 0) {
      _clipLayer.layer = null;
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & Size(constraints.crossAxisExtent, geometry!.paintExtent),
      (context, offset) => context.paintChild(child, offset + Offset(-_dx, 0)),
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    transform.multiply(Matrix4.translationValues(-_dx, 0, 0));
  }

  @override
  double childMainAxisPosition(RenderObject child) => 0;

  @override
  double childCrossAxisPosition(RenderObject child) => -_dx;

  @override
  double childScrollOffset(RenderObject child) => constraints.scrollOffset;

  @override
  bool hitTestChildren(SliverHitTestResult result,
      {required double mainAxisPosition, required double crossAxisPosition}) {
    final child = this.child;
    if (child == null) return false;
    return BoxHitTestResult.wrap(result).addWithPaintOffset(
      offset: Offset(-_dx, 0),
      position: Offset(crossAxisPosition, mainAxisPosition),
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}
