part of '../dashboard_base.dart';

/// The geometry of a laid-out [Dashboard], reported through
/// [Dashboard.onGridDimensionsChanged] on every layout pass.
///
/// All lengths are logical pixels. A slot's size includes the spacing around
/// the item in it: an item `w` slots wide away from the grid edges is
/// `w * slotWidth - horizontalSpace` wide.
class GridDimensions {
  /// Width of one enabled column.
  ///
  /// With [Dashboard.virtualColumnsConfig] the disabled columns have their own
  /// width and the enabled ones share the rest, so this is wider than
  /// `totalWidth / columns`.
  final double slotWidth;

  /// Height of one row: [Dashboard.slotHeight] when set, otherwise
  /// `totalWidth / columns / slotAspectRatio` (`slotAspectRatio` defaulting
  /// to 1). That divides by all [columns], disabled virtual ones included, so
  /// with virtual columns a row is shorter than [slotWidth] even at ratio 1.
  final double slotHeight;

  /// [Dashboard.slotCount], disabled virtual columns included.
  final int columns;

  /// Width of the grid without the horizontal [padding].
  final double totalWidth;

  /// Height of the viewport without the vertical [padding].
  final double totalHeight;

  /// [Dashboard.padding], resolved for the text direction.
  final EdgeInsets padding;

  /// [Dashboard.horizontalSpace]: the gap between two items side by side.
  final double horizontalSpace;

  /// [Dashboard.verticalSpace]: the gap between two items one above the other.
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
