part of '../dashboard_base.dart';

/// Enum for device type based on screen width
enum DeviceType { mobile, tablet, desktop }

/// Configuration for mobile carousel view
class MobileCarouselConfig {
  const MobileCarouselConfig({
    this.mobileBreakpoint = 600.0,
    this.tabletBreakpoint = 900.0,
    this.visibleSectionsOnMobile = 1,
    this.visibleSectionsOnTablet = 2,
    this.sectionStepOnTablet,
    this.showHeader = true,
    this.showDots = true,
    this.showArrows = true,
    this.dotColor = Colors.grey,
    this.activeDotColor = Colors.blue,
    this.arrowColor = Colors.blue,
    this.dotSize = 8.0,
    this.activeDotSize = 10.0,
    this.dotsSpacing = 8.0,
    this.arrowSize = 24.0,
    this.pageSnapping = true,
    this.swipeEnabled = true,
  });

  final double mobileBreakpoint;
  final double tabletBreakpoint;
  final int visibleSectionsOnMobile;
  final int visibleSectionsOnTablet;

  /// How many sections one page advances by on a tablet-width viewport.
  ///
  /// `null` means one section per page, which is what this widget has always
  /// done and therefore stays the default: a consumer that does not set the
  /// field sees exactly the behaviour of the previous release. With more than
  /// one section visible, a step of 1 makes consecutive pages overlap — with
  /// [visibleSectionsOnTablet] `= 2` page 0 shows S1+S2 and page 1 shows
  /// S2+S3, so S2 is on both. Setting the step to the number of visible
  /// sections pages the viewport section-block by section-block instead.
  ///
  /// The last page is clamped so the viewport is never left half empty: with
  /// 3 sections, 2 visible and a step of 2 there are 2 pages — S1+S2 and
  /// S2+S3 (page 1 starts at section 1, not at section 2). With 4 sections the
  /// same settings give 2 disjoint pages: S1+S2 and S3+S4.
  ///
  /// Only the tablet layout is configurable; the mobile layout, which shows a
  /// single section, always advances one section at a time.
  final int? sectionStepOnTablet;
  final bool showHeader;
  final bool showDots;
  final bool showArrows;
  final Color dotColor;
  final Color activeDotColor;
  final Color arrowColor;
  final double dotSize;
  final double activeDotSize;
  final double dotsSpacing;
  final double arrowSize;
  final bool pageSnapping;
  final bool swipeEnabled;

  DeviceType getDeviceType(double width) {
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// How many sections are visible at once on [deviceType].
  int _visibleSectionsFor(DeviceType deviceType) =>
      deviceType == DeviceType.mobile
          ? visibleSectionsOnMobile
          : visibleSectionsOnTablet;

  /// How many sections one page advances by on [deviceType].
  ///
  /// Never below 1 — a step of 0 would make every page start at section 0.
  int _sectionStepFor(DeviceType deviceType) => deviceType == DeviceType.mobile
      ? 1
      : max(1, sectionStepOnTablet ?? 1);

  /// Number of pages needed to walk [totalSections] sections on [deviceType].
  ///
  /// One page for as long as everything fits, then one more page per `step`
  /// sections left over: `ceil((sections - visible) / step) + 1`.
  @visibleForTesting
  int totalPagesFor(DeviceType deviceType, int totalSections) {
    final visible = _visibleSectionsFor(deviceType);
    if (totalSections <= visible) return 1;
    final step = _sectionStepFor(deviceType);
    return ((totalSections - visible + step - 1) ~/ step) + 1;
  }

  /// Index of the first section shown on [page].
  ///
  /// `page * step`, clamped to the last full viewport
  /// (`totalSections - visible`) so the final page shows a full set of
  /// sections instead of running past the end. See [sectionStepOnTablet].
  @visibleForTesting
  int sectionForPage(DeviceType deviceType, int totalSections, int page) {
    final lastStart = totalSections - _visibleSectionsFor(deviceType);
    if (lastStart <= 0) return 0;
    return max(0, min(page * _sectionStepFor(deviceType), lastStart));
  }
}

/// Defines how to split columns into pages for mobile view
class MobilePageBreaks {
  const MobilePageBreaks({required this.breakColumns});

  final List<int> breakColumns;

  factory MobilePageBreaks.fromVirtualColumns(
    VirtualColumnsConfig? config,
    int totalSlotCount,
  ) {
    if (config == null || config.disabledColumns.isEmpty) {
      return MobilePageBreaks(breakColumns: [totalSlotCount]);
    }

    final breaks = <int>[];
    final sorted = List<int>.from(config.disabledColumns)..sort();

    for (final col in sorted) {
      breaks.add(col);
    }
    breaks.add(totalSlotCount);

    return MobilePageBreaks(breakColumns: breaks);
  }

  int get pageCount => breakColumns.length;

  int getPageStartColumn(int pageIndex, VirtualColumnsConfig? config) {
    if (pageIndex == 0) return 0;
    if (pageIndex >= breakColumns.length) return breakColumns.last;
    final prevBreak = breakColumns[pageIndex - 1];
    return prevBreak + 1;
  }

  int getPageEndColumn(int pageIndex) {
    if (pageIndex >= breakColumns.length) return breakColumns.last;
    return breakColumns[pageIndex];
  }

  int getPageColumnCount(int pageIndex, VirtualColumnsConfig? config) {
    final start = getPageStartColumn(pageIndex, config);
    final end = getPageEndColumn(pageIndex);
    return end - start;
  }
}

/// A wrapper that shows Dashboard with sliding viewport on mobile/tablet devices
class MobileDashboardWrapper<T extends DashboardItem> extends StatefulWidget {
  const MobileDashboardWrapper({
    super.key,
    required this.dashboardBuilder,
    required this.dashboardItemController,
    required this.slotCount,
    this.columnsPerPage = 6,
    this.virtualColumnsConfig,
    this.mobileConfig = const MobileCarouselConfig(),
    this.onPageChanged,
  });

  final Widget Function(
    DashboardItemController<T> controller,
    int slotCount,
    int startColumn,
    bool isMobile,
  ) dashboardBuilder;

  final DashboardItemController<T> dashboardItemController;
  final int slotCount;
  final int columnsPerPage;
  final VirtualColumnsConfig? virtualColumnsConfig;
  final MobileCarouselConfig mobileConfig;
  final void Function(int page)? onPageChanged;

  @override
  State<MobileDashboardWrapper<T>> createState() =>
      _MobileDashboardWrapperState<T>();
}

class _MobileDashboardWrapperState<T extends DashboardItem>
    extends State<MobileDashboardWrapper<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Current page (source of truth for position)
  int _currentPage = 0;

  // Animation: from which offset to which offset (in pixels)
  double _animationStartOffset = 0.0;
  double _animationEndOffset = 0.0;

  // Drag: progress as fraction of page width (can be negative or > 1)
  double _dragProgress = 0.0;
  bool _isDragging = false;

  double _lastSlotWidth = 0.0;
  double _lastResolvedWidth = 0.0;

  late MobilePageBreaks _pageBreaks;
  DeviceType _currentDeviceType = DeviceType.desktop;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.addListener(() {
      setState(() {});
    });
    _updatePageBreaks();
  }

  @override
  void didUpdateWidget(MobileDashboardWrapper<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.virtualColumnsConfig != widget.virtualColumnsConfig ||
        oldWidget.slotCount != widget.slotCount ||
        oldWidget.columnsPerPage != widget.columnsPerPage) {
      _updatePageBreaks();
    }
  }

  void _updatePageBreaks() {
    if (widget.virtualColumnsConfig != null) {
      _pageBreaks = MobilePageBreaks.fromVirtualColumns(
        widget.virtualColumnsConfig,
        widget.slotCount,
      );
    } else {
      final breaks = <int>[];
      for (int i = widget.columnsPerPage;
          i <= widget.slotCount;
          i += widget.columnsPerPage) {
        breaks.add(i);
      }
      if (breaks.isEmpty || breaks.last != widget.slotCount) {
        breaks.add(widget.slotCount);
      }
      _pageBreaks = MobilePageBreaks(breakColumns: breaks);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int get _totalSections => _pageBreaks.pageCount;

  int _getTotalPages(DeviceType deviceType) =>
      widget.mobileConfig.totalPagesFor(deviceType, _totalSections);

  /// First section shown on [page] for the device type currently laid out.
  ///
  /// With the default step of 1 this is the page index itself, which is what
  /// the whole widget assumed before [MobileCarouselConfig.sectionStepOnTablet]
  /// existed.
  int _sectionForPage(int page) => widget.mobileConfig
      .sectionForPage(_currentDeviceType, _totalSections, page);

  /// Get number of enabled and disabled columns for sections from startSection to endSection (inclusive)
  ({int enabled, int disabled}) _getColumnsForSections(
      int startSection, int endSection) {
    int enabled = 0;
    int disabled = 0;
    for (int i = startSection; i <= endSection && i < _totalSections; i++) {
      enabled +=
          _pageBreaks.getPageColumnCount(i, widget.virtualColumnsConfig);
      if (i < endSection && i < _totalSections - 1) {
        disabled += 1;
      }
    }
    return (enabled: enabled, disabled: disabled);
  }

  /// Get start column for page
  int _getStartColumnForPage(int page) {
    return _pageBreaks.getPageStartColumn(
        _sectionForPage(page), widget.virtualColumnsConfig);
  }

  /// Calculate pixel offset for a given page using actual column positions
  double _getOffsetForPage(int page, double slotWidth, double resolvedWidth) {
    if (page <= 0) return 0;
    final startColumn = _getStartColumnForPage(page);
    if (widget.virtualColumnsConfig != null) {
      return widget.virtualColumnsConfig!
          .getColumnPosition(startColumn, slotWidth, resolvedWidth);
    }
    return startColumn * slotWidth;
  }

  void _animateToPage(int page, int totalPages) {
    page = page.clamp(0, totalPages - 1);
    if (page == _currentPage && !_isDragging) return;

    _animationStartOffset =
        _getOffsetForPage(_currentPage, _lastSlotWidth, _lastResolvedWidth);
    _animationEndOffset =
        _getOffsetForPage(page, _lastSlotWidth, _lastResolvedWidth);
    _isDragging = false;
    _dragProgress = 0.0;

    _animationController.forward(from: 0).then((_) {
      if (_currentPage != page) {
        _currentPage = page;
        widget.onPageChanged?.call(page);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType =
            widget.mobileConfig.getDeviceType(constraints.maxWidth);

        if (_currentDeviceType != deviceType) {
          _currentDeviceType = deviceType;
          final maxPage = _getTotalPages(deviceType) - 1;
          if (_currentPage > maxPage) {
            _currentPage = maxPage;
          }
          // Reset animation state on device type change
          _animationStartOffset = 0.0;
          _animationEndOffset = 0.0;
          _dragProgress = 0.0;
          _isDragging = false;
        }

        switch (deviceType) {
          case DeviceType.mobile:
          case DeviceType.tablet:
            return _buildSlidingDashboard(constraints, deviceType);
          case DeviceType.desktop:
            return widget.dashboardBuilder(
              widget.dashboardItemController,
              widget.slotCount,
              0,
              false,
            );
        }
      },
    );
  }

  Widget _buildSlidingDashboard(
      BoxConstraints constraints, DeviceType deviceType) {
    final totalPages = _getTotalPages(deviceType);
    final visibleSections = deviceType == DeviceType.mobile
        ? widget.mobileConfig.visibleSectionsOnMobile
        : widget.mobileConfig.visibleSectionsOnTablet;

    // Calculate visible enabled and disabled columns for current view
    final visibleCols = _getColumnsForSections(0, visibleSections - 1);

    // Slot width based on visible columns fitting in viewport.
    // Disabled columns take a percentage of the total resolved width, not slotWidth,
    // so we must solve for slotWidth accounting for their actual size.
    const padding = 8.0;
    final contentWidth = constraints.maxWidth - (padding * 2);

    final vc = widget.virtualColumnsConfig;
    final totalDisabled = vc?.disabledColumns.length ?? 0;
    final totalEnabled = widget.slotCount - totalDisabled;
    final dcw = vc?.disabledColumnWidth ?? 0.0;

    double slotWidth;
    double resolvedWidth;

    if (totalDisabled > 0 && dcw > 0 && totalEnabled > 0) {
      // Ratio of disabled column width to enabled column width:
      // disabledColWidth = dcw * resolvedWidth
      // enabledSlotWidth = resolvedWidth * (1 - totalDisabled * dcw) / totalEnabled
      // ratio = disabledColWidth / enabledSlotWidth = dcw * totalEnabled / (1 - totalDisabled * dcw)
      final disabledToEnabledRatio =
          dcw * totalEnabled / (1.0 - totalDisabled * dcw);
      final effectiveVisibleSlots =
          visibleCols.enabled + visibleCols.disabled * disabledToEnabledRatio;
      slotWidth = contentWidth / effectiveVisibleSlots;
      resolvedWidth = slotWidth * totalEnabled / (1.0 - totalDisabled * dcw);
    } else {
      slotWidth = contentWidth / (visibleCols.enabled + visibleCols.disabled);
      resolvedWidth = widget.slotCount * slotWidth;
    }

    _lastSlotWidth = slotWidth;
    _lastResolvedWidth = resolvedWidth;

    // Full dashboard width = resolved content + Dashboard padding on both sides
    final fullDashboardWidth = resolvedWidth + (padding * 2);

    // Calculate current offset based on state
    double currentOffset;
    if (_animationController.isAnimating) {
      // During animation: interpolate between start and end offsets
      final t = Curves.easeOut.transform(_animationController.value);
      currentOffset = _animationStartOffset +
          (_animationEndOffset - _animationStartOffset) * t;
    } else if (_isDragging) {
      // During drag: current page offset + drag progress
      final pageOffset =
          _getOffsetForPage(_currentPage, slotWidth, resolvedWidth);
      // Calculate how many pixels is one "page step"
      final nextPageOffset = _getOffsetForPage(
        (_currentPage + 1).clamp(0, totalPages - 1),
        slotWidth,
        resolvedWidth,
      );
      final prevPageOffset = _getOffsetForPage(
        (_currentPage - 1).clamp(0, totalPages - 1),
        slotWidth,
        resolvedWidth,
      );

      if (_dragProgress >= 0) {
        // Dragging forward (to next page)
        final stepSize = nextPageOffset - pageOffset;
        currentOffset = pageOffset + _dragProgress * stepSize;
      } else {
        // Dragging backward (to prev page)
        final stepSize = pageOffset - prevPageOffset;
        currentOffset = pageOffset + _dragProgress * stepSize;
      }

      // Clamp to valid range
      final maxOffset =
          _getOffsetForPage(totalPages - 1, slotWidth, resolvedWidth);
      currentOffset = currentOffset.clamp(0.0, maxOffset);
    } else {
      // Static: just current page
      currentOffset =
          _getOffsetForPage(_currentPage, slotWidth, resolvedWidth);
    }

    // Header text. Page index and section index part ways as soon as the step
    // is bigger than 1, so the header is written from the section.
    final firstSection = _sectionForPage(_currentPage);
    String headerText;
    if (visibleSections == 1) {
      headerText = 'Sekcja ${firstSection + 1} z $_totalSections';
    } else {
      final lastSection =
          (firstSection + visibleSections).clamp(1, _totalSections);
      headerText = 'Sekcje ${firstSection + 1}-$lastSection z $_totalSections';
    }

    return Column(
      children: [
        if (widget.mobileConfig.showHeader)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.mobileConfig.showArrows && _currentPage > 0)
                  IconButton(
                    onPressed: () =>
                        _animateToPage(_currentPage - 1, totalPages),
                    icon: Icon(Icons.chevron_left,
                        color: widget.mobileConfig.arrowColor),
                    iconSize: widget.mobileConfig.arrowSize,
                  ),
                Text(
                  headerText,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (widget.mobileConfig.showArrows &&
                    _currentPage < totalPages - 1)
                  IconButton(
                    onPressed: () =>
                        _animateToPage(_currentPage + 1, totalPages),
                    icon: Icon(Icons.chevron_right,
                        color: widget.mobileConfig.arrowColor),
                    iconSize: widget.mobileConfig.arrowSize,
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.dashboardItemController,
            builder: (context, _) {
              final isEditMode = widget.dashboardItemController.isEditing;

              return GestureDetector(
                onHorizontalDragStart:
                    (widget.mobileConfig.swipeEnabled && !isEditMode)
                        ? (details) {
                            _animationController.stop();
                            _isDragging = true;
                            _dragProgress = 0.0;
                          }
                        : null,
                onHorizontalDragUpdate:
                    (widget.mobileConfig.swipeEnabled && !isEditMode)
                        ? (details) {
                            setState(() {
                              // Convert pixel delta to page fraction
                              // Negative delta.dx = dragging left = moving to next page
                              _dragProgress -=
                                  details.delta.dx / constraints.maxWidth;
                            });
                          }
                        : null,
                onHorizontalDragEnd: (widget.mobileConfig.swipeEnabled &&
                        !isEditMode)
                    ? (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        int targetPage;

                        if (velocity.abs() > 500) {
                          // Fast swipe
                          targetPage = velocity < 0
                              ? _currentPage + 1
                              : _currentPage - 1;
                        } else {
                          // Slow drag - snap based on progress
                          if (_dragProgress > 0.3) {
                            targetPage = _currentPage + 1;
                          } else if (_dragProgress < -0.3) {
                            targetPage = _currentPage - 1;
                          } else {
                            targetPage = _currentPage;
                          }
                        }

                        // Calculate current visual offset before resetting drag
                        final pageOffset = _getOffsetForPage(
                            _currentPage, slotWidth, resolvedWidth);
                        final nextPageOffset = _getOffsetForPage(
                          (_currentPage + 1).clamp(0, totalPages - 1),
                          slotWidth,
                          resolvedWidth,
                        );
                        final prevPageOffset = _getOffsetForPage(
                          (_currentPage - 1).clamp(0, totalPages - 1),
                          slotWidth,
                          resolvedWidth,
                        );
                        double visualOffset;
                        if (_dragProgress >= 0) {
                          final stepSize = nextPageOffset - pageOffset;
                          visualOffset =
                              pageOffset + _dragProgress * stepSize;
                        } else {
                          final stepSize = pageOffset - prevPageOffset;
                          visualOffset =
                              pageOffset + _dragProgress * stepSize;
                        }
                        final maxOffset = _getOffsetForPage(
                            totalPages - 1, slotWidth, resolvedWidth);
                        visualOffset =
                            visualOffset.clamp(0.0, maxOffset);

                        final clampedTarget =
                            targetPage.clamp(0, totalPages - 1);
                        _animationStartOffset = visualOffset;
                        _animationEndOffset = _getOffsetForPage(
                            clampedTarget, slotWidth, resolvedWidth);
                        _currentPage = clampedTarget;
                        _isDragging = false;
                        _dragProgress = 0.0;

                        _animationController.forward(from: 0).then((_) {
                          widget.onPageChanged?.call(_currentPage);
                        });
                      }
                    : null,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxWidth: fullDashboardWidth,
                    minWidth: fullDashboardWidth,
                    child: Transform.translate(
                      offset: Offset(-currentOffset, 0),
                      child: widget.dashboardBuilder(
                        widget.dashboardItemController,
                        widget.slotCount,
                        0,
                        true,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.mobileConfig.showDots && totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                final isActive = index == _currentPage;
                return GestureDetector(
                  onTap: () => _animateToPage(index, totalPages),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(
                        horizontal: widget.mobileConfig.dotsSpacing / 2),
                    width: isActive
                        ? widget.mobileConfig.activeDotSize
                        : widget.mobileConfig.dotSize,
                    height: isActive
                        ? widget.mobileConfig.activeDotSize
                        : widget.mobileConfig.dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? widget.mobileConfig.activeDotColor
                          : widget.mobileConfig.dotColor,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
