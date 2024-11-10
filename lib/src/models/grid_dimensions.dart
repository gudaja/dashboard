part of '../dashboard_base.dart';

class GridDimensions {
  final double slotWidth;
  final double slotHeight;
  final int columns;
  final double totalWidth;
  final double totalHeight;
  final EdgeInsets padding;
  final double horizontalSpace;
  final double verticalSpace;

  const GridDimensions({
    required this.slotWidth,
    required this.slotHeight,
    required this.columns,
    required this.totalWidth,
    required this.totalHeight,
    required this.padding,
    required this.horizontalSpace,
    required this.verticalSpace,
  });
}
