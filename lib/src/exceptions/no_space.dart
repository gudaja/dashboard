part of '../dashboard_base.dart';

/// Thrown by [DashboardItemController.add] and
/// [DashboardItemController.addAll] when an item has no free place within
/// [Dashboard.maxRows].
///
/// Without a row ceiling the grid grows downwards and every item finds a
/// place, so this is only ever thrown when [Dashboard.maxRows] is set. The
/// grid is left as it was before the call: [addAll] adds none of its items
/// when one of them does not fit.
///
/// Use [DashboardItemController.canPlace] to check a layout first.
class DashboardNoSpaceException implements Exception {
  /// An item [identifier] with [layout] found no place within [maxRows] rows.
  DashboardNoSpaceException(
      {required this.identifier, required this.layout, required this.maxRows});

  /// The identifier of the item that did not fit.
  final String identifier;

  /// The layout the item was added with.
  final ItemLayout layout;

  /// The row ceiling of the grid ([Dashboard.maxRows]).
  final int maxRows;

  @override
  String toString() => 'DashboardNoSpaceException: no free place for '
      '"$identifier" ($layout) within $maxRows rows';
}
