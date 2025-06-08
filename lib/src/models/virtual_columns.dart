part of '../dashboard_base.dart';

/// Virtual columns configuration for Dashboard
class VirtualColumnsConfig {
  /// List of disabled columns indices (0-based)
  final List<int> disabledColumns;

  /// Width of disabled columns in logical pixels
  /// If null, disabled columns have zero width (completely hidden)
  final double? disabledColumnWidth;

  /// Whether disabled columns should be visible but not interactable
  final bool showDisabledColumns;

  const VirtualColumnsConfig({
    required this.disabledColumns,
    this.disabledColumnWidth,
    this.showDisabledColumns = true,
  });

  /// Create config with completely hidden disabled columns
  const VirtualColumnsConfig.hidden({
    required this.disabledColumns,
  })  : disabledColumnWidth = null,
        showDisabledColumns = false;

  /// Create config with visible but disabled columns
  const VirtualColumnsConfig.visible({
    required this.disabledColumns,
    this.disabledColumnWidth = 40.0,
  }) : showDisabledColumns = true;

  /// Check if column is disabled
  bool isColumnDisabled(int column) {
    return disabledColumns.contains(column);
  }

  /// Get effective width for a column
  double getColumnWidth(int column, double normalSlotWidth) {
    if (isColumnDisabled(column)) {
      return disabledColumnWidth ?? 0.0;
    }
    return normalSlotWidth;
  }

  /// Calculate total grid width including virtual columns
  double calculateTotalWidth(int totalColumns, double normalSlotWidth) {
    double totalWidth = 0.0;
    for (int i = 0; i < totalColumns; i++) {
      totalWidth += getColumnWidth(i, normalSlotWidth);
    }
    return totalWidth;
  }

  /// Get the X position for a column considering virtual columns
  double getColumnPosition(int column, double normalSlotWidth) {
    double position = 0.0;
    for (int i = 0; i < column; i++) {
      position += getColumnWidth(i, normalSlotWidth);
    }
    return position;
  }

  /// Find the next enabled column after given column
  int? getNextEnabledColumn(int fromColumn, int maxColumns) {
    for (int i = fromColumn + 1; i < maxColumns; i++) {
      if (!isColumnDisabled(i)) {
        return i;
      }
    }
    return null;
  }

  /// Find the previous enabled column before given column
  int? getPreviousEnabledColumn(int fromColumn) {
    for (int i = fromColumn - 1; i >= 0; i--) {
      if (!isColumnDisabled(i)) {
        return i;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VirtualColumnsConfig &&
        other.disabledColumns.toString() == disabledColumns.toString() &&
        other.disabledColumnWidth == disabledColumnWidth &&
        other.showDisabledColumns == showDisabledColumns;
  }

  @override
  int get hashCode {
    return disabledColumns.hashCode ^
        disabledColumnWidth.hashCode ^
        showDisabledColumns.hashCode;
  }

  @override
  String toString() {
    return 'VirtualColumnsConfig(disabledColumns: $disabledColumns, '
        'disabledColumnWidth: $disabledColumnWidth, '
        'showDisabledColumns: $showDisabledColumns)';
  }
}
