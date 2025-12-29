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

  // Animation: from which page to which page
  int _animationStartPage = 0;
  int _animationEndPage = 0;

  // Drag: progress as fraction of page width (can be negative or > 1)
  double _dragProgress = 0.0;
  bool _isDragging = false;

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

  int _getTotalPages(DeviceType deviceType) {
    final visibleSections = deviceType == DeviceType.mobile
        ? widget.mobileConfig.visibleSectionsOnMobile
        : widget.mobileConfig.visibleSectionsOnTablet;
    final pages = _totalSections - (visibleSections - 1);
    return pages > 0 ? pages : 1;
  }

  /// Get number of columns for sections from startSection to endSection (inclusive)
  int _getColumnsForSections(int startSection, int endSection) {
    int columns = 0;
    for (int i = startSection; i <= endSection && i < _totalSections; i++) {
      columns += _pageBreaks.getPageColumnCount(i, widget.virtualColumnsConfig);
      if (i < endSection && i < _totalSections - 1) {
        columns += 1; // disabled column
      }
    }
    return columns;
  }

  /// Get start column for page
  int _getStartColumnForPage(int page) {
    return _pageBreaks.getPageStartColumn(page, widget.virtualColumnsConfig);
  }

  /// Calculate pixel offset for a given page
  double _getOffsetForPage(int page, double slotWidth) {
    if (page <= 0) return 0;
    final startColumn = _getStartColumnForPage(page);
    return startColumn * slotWidth;
  }

  void _animateToPage(int page, int totalPages) {
    page = page.clamp(0, totalPages - 1);
    if (page == _currentPage && !_isDragging) return;

    _animationStartPage = _currentPage;
    _animationEndPage = page;
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
          _animationStartPage = _currentPage;
          _animationEndPage = _currentPage;
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

    // Calculate visible columns for current view
    final visibleColumns = _getColumnsForSections(0, visibleSections - 1);

    // Slot width based on visible columns fitting in viewport
    const padding = 8.0;
    final contentWidth = constraints.maxWidth - (padding * 2);
    final slotWidth = contentWidth / visibleColumns;

    // Full dashboard width
    final fullDashboardWidth = widget.slotCount * slotWidth + (padding * 2);

    // Calculate current offset based on state
    double currentOffset;
    if (_animationController.isAnimating) {
      // During animation: interpolate between start and end pages
      final startOffset = _getOffsetForPage(_animationStartPage, slotWidth);
      final endOffset = _getOffsetForPage(_animationEndPage, slotWidth);
      final t = Curves.easeOut.transform(_animationController.value);
      currentOffset = startOffset + (endOffset - startOffset) * t;
    } else if (_isDragging) {
      // During drag: current page offset + drag progress
      final pageOffset = _getOffsetForPage(_currentPage, slotWidth);
      // Calculate how many pixels is one "page step"
      final nextPageOffset = _getOffsetForPage(
        (_currentPage + 1).clamp(0, totalPages - 1),
        slotWidth,
      );
      final prevPageOffset = _getOffsetForPage(
        (_currentPage - 1).clamp(0, totalPages - 1),
        slotWidth,
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
      final maxOffset = _getOffsetForPage(totalPages - 1, slotWidth);
      currentOffset = currentOffset.clamp(0.0, maxOffset);
    } else {
      // Static: just current page
      currentOffset = _getOffsetForPage(_currentPage, slotWidth);
    }

    // Header text
    String headerText;
    if (visibleSections == 1) {
      headerText = 'Sekcja ${_currentPage + 1} z $_totalSections';
    } else {
      final firstSection = _currentPage + 1;
      final lastSection =
          (_currentPage + visibleSections).clamp(1, _totalSections);
      headerText = 'Sekcje $firstSection-$lastSection z $_totalSections';
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

                        // Animate from current visual position
                        _animationStartPage = _currentPage;
                        _animationEndPage = targetPage.clamp(0, totalPages - 1);
                        _currentPage = _animationEndPage;
                        _isDragging = false;
                        _dragProgress = 0.0;

                        if (_animationStartPage != _animationEndPage) {
                          _animationController.forward(from: 0).then((_) {
                            widget.onPageChanged?.call(_currentPage);
                          });
                        } else {
                          // Snap back to current page
                          _animationController.forward(from: 0);
                        }
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
