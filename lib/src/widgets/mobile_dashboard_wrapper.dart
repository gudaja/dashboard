part of '../dashboard_base.dart';

/// Configuration for mobile carousel view
class MobileCarouselConfig {
  const MobileCarouselConfig({
    this.mobileBreakpoint = 600.0,
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

  /// Width threshold below which mobile view is activated
  final double mobileBreakpoint;

  /// Show section header with "Sekcja X z Y" and navigation arrows
  final bool showHeader;

  /// Show page indicator dots
  final bool showDots;

  /// Show navigation arrows on sides (in header)
  final bool showArrows;

  /// Inactive dot color
  final Color dotColor;

  /// Active dot color
  final Color activeDotColor;

  /// Arrow buttons color
  final Color arrowColor;

  /// Inactive dot size
  final double dotSize;

  /// Active dot size
  final double activeDotSize;

  /// Spacing between dots
  final double dotsSpacing;

  /// Arrow icon size
  final double arrowSize;

  /// Whether pages should snap to position
  final bool pageSnapping;

  /// Whether swipe gesture is enabled
  final bool swipeEnabled;
}

/// Defines how to split columns into pages for mobile view
class MobilePageBreaks {
  const MobilePageBreaks({
    required this.breakColumns,
  });

  /// Columns where page breaks occur (exclusive end of each page)
  /// For example, [6, 13, 20] means:
  /// - Page 0: columns 0-5 (before column 6)
  /// - Page 1: columns 7-12 (between 6 and 13, skipping disabled 6)
  /// - Page 2: columns 14-19 (between 13 and 20, skipping disabled 13)
  final List<int> breakColumns;

  /// Create breaks from VirtualColumnsConfig - pages split at disabled columns
  factory MobilePageBreaks.fromVirtualColumns(
    VirtualColumnsConfig? config,
    int totalSlotCount,
  ) {
    if (config == null || config.disabledColumns.isEmpty) {
      // No virtual columns - just use total as single page
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

  /// Get start column for a page (first non-disabled column)
  int getPageStartColumn(int pageIndex, VirtualColumnsConfig? config) {
    if (pageIndex == 0) return 0;
    if (pageIndex >= breakColumns.length) return breakColumns.last;

    // Start after the previous break column (which is a disabled column)
    final prevBreak = breakColumns[pageIndex - 1];
    // Skip the disabled column itself
    return prevBreak + 1;
  }

  /// Get end column for a page (exclusive)
  int getPageEndColumn(int pageIndex) {
    if (pageIndex >= breakColumns.length) return breakColumns.last;
    return breakColumns[pageIndex];
  }

  /// Get number of visible columns in a page
  int getPageColumnCount(int pageIndex, VirtualColumnsConfig? config) {
    final start = getPageStartColumn(pageIndex, config);
    final end = getPageEndColumn(pageIndex);
    return end - start;
  }
}

/// A wrapper that shows Dashboard in carousel mode on mobile devices
///
/// Shows full Dashboard functionality but divided into "pages" based on
/// virtual column separators (disabled columns). Each page shows a section
/// between two disabled columns with full drag/resize capabilities.
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

  /// Builder for the Dashboard widget
  /// Parameters:
  /// - controller: The dashboard item controller
  /// - slotCount: Number of slots for this view
  /// - startColumn: Starting column offset (0 in desktop, varies in mobile)
  /// - isMobile: Whether we're in mobile view
  final Widget Function(
    DashboardItemController<T> controller,
    int slotCount,
    int startColumn,
    bool isMobile,
  ) dashboardBuilder;

  /// The dashboard item controller
  final DashboardItemController<T> dashboardItemController;

  /// Total number of grid slots/columns
  final int slotCount;

  /// How many grid columns each carousel page shows in mobile view
  /// (used when no virtualColumnsConfig is provided)
  final int columnsPerPage;

  /// Virtual columns configuration - if provided, pages will be split
  /// at disabled columns instead of using columnsPerPage
  final VirtualColumnsConfig? virtualColumnsConfig;

  /// Configuration for mobile carousel appearance
  final MobileCarouselConfig mobileConfig;

  /// Callback when carousel page changes
  final void Function(int page)? onPageChanged;

  @override
  State<MobileDashboardWrapper<T>> createState() =>
      _MobileDashboardWrapperState<T>();
}

class _MobileDashboardWrapperState<T extends DashboardItem>
    extends State<MobileDashboardWrapper<T>> {
  late PageController _pageController;
  int _currentPage = 0;
  late MobilePageBreaks _pageBreaks;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
      // No virtual columns - create regular breaks based on columnsPerPage
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
    _pageController.dispose();
    super.dispose();
  }

  int get _totalPages => _pageBreaks.pageCount;

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < widget.mobileConfig.mobileBreakpoint;

        if (isMobile) {
          return _buildMobileCarousel(constraints);
        } else {
          // Desktop: full dashboard with all columns
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

  Widget _buildMobileCarousel(BoxConstraints constraints) {
    return Column(
      children: [
        // Page header showing current section (optional)
        if (widget.mobileConfig.showHeader)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.mobileConfig.showArrows && _currentPage > 0)
                  IconButton(
                    onPressed: () => _goToPage(_currentPage - 1),
                    icon: Icon(
                      Icons.chevron_left,
                      color: widget.mobileConfig.arrowColor,
                    ),
                    iconSize: widget.mobileConfig.arrowSize,
                  ),
                Text(
                  'Sekcja ${_currentPage + 1} z $_totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.mobileConfig.showArrows &&
                    _currentPage < _totalPages - 1)
                  IconButton(
                    onPressed: () => _goToPage(_currentPage + 1),
                    icon: Icon(
                      Icons.chevron_right,
                      color: widget.mobileConfig.arrowColor,
                    ),
                    iconSize: widget.mobileConfig.arrowSize,
                  ),
              ],
            ),
          ),

        // Main carousel - each page clips and translates the full dashboard
        Expanded(
          child: ScrollConfiguration(
            // Enable mouse drag scrolling on desktop/web
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: PageView.builder(
              controller: _pageController,
              physics: widget.mobileConfig.swipeEnabled
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              pageSnapping: widget.mobileConfig.pageSnapping,
              itemCount: _totalPages,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
                widget.onPageChanged?.call(page);
              },
              itemBuilder: (context, pageIndex) {
                return _buildPageWithClippedDashboard(
                  pageIndex,
                  constraints.maxWidth,
                );
              },
            ),
          ),
        ),

        // Page indicator dots
        if (widget.mobileConfig.showDots && _totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildDotsIndicator(),
          ),
      ],
    );
  }

  Widget _buildPageWithClippedDashboard(int pageIndex, double viewportWidth) {
    final startColumn =
        _pageBreaks.getPageStartColumn(pageIndex, widget.virtualColumnsConfig);
    final endColumn = _pageBreaks.getPageEndColumn(pageIndex);
    final pageColumns = endColumn - startColumn;

    // Dashboard has internal padding (usually 8px on each side)
    // We need to account for this in our calculations
    const dashboardPadding = 8.0;

    // The visible content area (excluding padding on both sides)
    final contentWidth = viewportWidth - (dashboardPadding * 2);

    // Calculate the section width ratio based on this page's columns
    final sectionWidthRatio = pageColumns / widget.slotCount;

    // Full dashboard content width (scaled to show section at full content width)
    final fullContentWidth = contentWidth / sectionWidthRatio;

    // Full dashboard width including padding
    final fullDashboardWidth = fullContentWidth + (dashboardPadding * 2);

    // Width of one slot in the full dashboard (based on content, not padding)
    final slotWidth = fullContentWidth / widget.slotCount;

    // Offset to show the current section (startColumn position)
    final offsetX = startColumn * slotWidth;

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: fullDashboardWidth,
        minWidth: fullDashboardWidth,
        child: Transform.translate(
          offset: Offset(-offsetX, 0),
          child: widget.dashboardBuilder(
            widget.dashboardItemController,
            widget.slotCount,
            startColumn,
            true,
          ),
        ),
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        final isActive = index == _currentPage;
        return GestureDetector(
          onTap: () => _goToPage(index),
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
    );
  }
}
