part of '../dashboard_base.dart';

/// Slot background builder.
abstract class SlotBackgroundBuilder<T extends DashboardItem> {
  SlotBackgroundBuilder();

  /// Create a builder with a function.
  static SlotBackgroundBuilder<T> withFunction<T extends DashboardItem>(
      Widget? Function(
              BuildContext context, T? item, int x, int y, bool editing)
          builder) {
    return _WithFunctionSlotBackgroundBuilder<T>(builder);
  }

  /// Create a builder with a function that has access to virtual columns config.
  static SlotBackgroundBuilder<T>
      withVirtualColumnsFunction<T extends DashboardItem>(
          Widget? Function(BuildContext context, T? item, int x, int y,
                  bool editing, VirtualColumnsConfig? virtualConfig)
              builder) {
    return _WithVirtualColumnsSlotBackgroundBuilder<T>(builder);
  }

  /// Create a builder with a function that has access to slot dimensions.
  static SlotBackgroundBuilder<T>
      withDimensionsFunction<T extends DashboardItem>(
          Widget? Function(
                  BuildContext context,
                  T? item,
                  int x,
                  int y,
                  bool editing,
                  double slotWidth,
                  double slotHeight,
                  VirtualColumnsConfig? virtualConfig)
              builder) {
    return _WithDimensionsSlotBackgroundBuilder<T>(builder);
  }

  DashboardItemController<T>? _itemController;

  /// The background of the slot at `[x, y]`, or `null` when it draws nothing.
  ///
  /// `null` used to become an empty `Container()`, so a slot the consumer did not
  /// want still cost a widget — plus the `Positioned` > `RepaintBoundary` >
  /// `Builder` the stack wrapped it in. A cockpit standing on a wallpaper answers
  /// `null` for EVERY slot, i.e. it paid the full price of a layer that draws
  /// nothing at all; the stack now skips such a slot entirely.
  ///
  /// [buildBackground] — the public half of this pair — has always been able to
  /// answer `null`, so nothing outside the package changes.
  Widget? _build(BuildContext context, int x, int y) {
    final layoutController = _itemController!._layoutController!;
    final i = layoutController._indexesTree[layoutController.getIndex([x, y])];

    T? item;

    if (i != null) {
      item = layoutController.itemController._items[i] as T;
    }

    return buildBackground(context, item, x, y, layoutController._isEditing);
  }

  /// Build background widget.
  Widget? buildBackground(
      BuildContext context, T? item, int x, int y, bool editing);
}

class _WithFunctionSlotBackgroundBuilder<T extends DashboardItem>
    extends SlotBackgroundBuilder<T> {
  final Widget? Function(
      BuildContext context, T? item, int x, int y, bool editing) builder;

  _WithFunctionSlotBackgroundBuilder(this.builder);

  @override
  Widget? buildBackground(
      BuildContext context, T? item, int x, int y, bool editing) {
    return builder(context, item, x, y, editing);
  }
}

class _WithVirtualColumnsSlotBackgroundBuilder<T extends DashboardItem>
    extends SlotBackgroundBuilder<T> {
  final Widget? Function(BuildContext context, T? item, int x, int y,
      bool editing, VirtualColumnsConfig? virtualConfig) builder;

  _WithVirtualColumnsSlotBackgroundBuilder(this.builder);

  @override
  Widget? buildBackground(
      BuildContext context, T? item, int x, int y, bool editing) {
    final virtualConfig =
        _itemController!._layoutController!.virtualColumnsConfig;
    return builder(context, item, x, y, editing, virtualConfig);
  }
}

class _WithDimensionsSlotBackgroundBuilder<T extends DashboardItem>
    extends SlotBackgroundBuilder<T> {
  final Widget? Function(
      BuildContext context,
      T? item,
      int x,
      int y,
      bool editing,
      double slotWidth,
      double slotHeight,
      VirtualColumnsConfig? virtualConfig) builder;

  _WithDimensionsSlotBackgroundBuilder(this.builder);

  @override
  Widget? buildBackground(
      BuildContext context, T? item, int x, int y, bool editing) {
    final layoutController = _itemController!._layoutController!;
    final virtualConfig = layoutController.virtualColumnsConfig;
    final slotWidth = layoutController.getColumnWidth(x);
    final slotHeight = layoutController.verticalSlotEdge;

    return builder(
        context, item, x, y, editing, slotWidth, slotHeight, virtualConfig);
  }
}
