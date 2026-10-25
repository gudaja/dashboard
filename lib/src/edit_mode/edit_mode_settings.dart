part of '../dashboard_base.dart';

/// Callback function for custom resize handle widget
typedef ResizeHandleBuilder<T extends DashboardItem> = Widget Function(
  BuildContext context,
  T item,
  bool isEditing,
);

/// Callback function for custom delete handle widget
typedef DeleteHandleBuilder<T extends DashboardItem> = Widget Function(
  BuildContext context,
  T item,
  bool isEditing,
  VoidCallback onDelete,
);

/// Edit mode settings.
/// It contains parameters related to gesture, animations, resizing.
class EditModeSettings {
  /// duration default is package:flutter/foundation.dart
  /// [kThemeAnimationDuration]
  EditModeSettings({
    this.resizeCursorSide = 10,
    this.resizeHysteresis = 0.05,
    this.paintBackgroundLines = true,
    this.fillEditingBackground = true,
    this.longPressEnabled = true,
    this.panEnabled = true,
    this.backgroundStyle = const EditModeBackgroundStyle(),
    this.curve = Curves.easeOut,
    Duration? duration,
    this.shrinkOnMove = true,
    this.draggableOutside = true,
    this.autoScroll = true,
    this.resizeHandleBuilder,
    this.deleteHandleBuilder,
  })  : assert(resizeHysteresis >= 0 && resizeHysteresis < 0.5,
            'resizeHysteresis is a fraction of a slot, from 0 to under 0.5'),
        duration = duration ?? kThemeAnimationDuration;

  /// If [draggableOutside] is true, items can be dragged outside the viewport.
  /// Else items can't be dragged outside the viewport.
  ///
  /// This only effects horizontal drag. To disable vertical drag set
  /// [autoScroll] to false also.
  final bool draggableOutside;

  /// If [autoScroll] is true, viewport will scroll automatically when item is
  /// dragged outside the viewport vertically.
  final bool autoScroll;

  /// Animation duration
  final Duration duration;

  /// Start resize or move with long press.
  final bool longPressEnabled;

  /// Start resize or move with pan.
  final bool panEnabled;

  /// Animation curve
  final Curve curve;

  /// Shrink items on moving if necessary.
  final bool shrinkOnMove;

  /// Resize side width. If pan/longPress start in side editing is resizing.
  final double resizeCursorSide;

  /// Hysteresis of a resize, as a fraction of a slot.
  ///
  /// An edge changes the size by one slot once it is past the middle of the
  /// slot by this much: with the default 0.05 an item grows when its edge is
  /// 55% into the next slot, and shrinks when it is 55% back into its own
  /// last one. After a step, going back by less than twice this much does not
  /// undo it, so an edge held near the middle does not flicker.
  final double resizeHysteresis;

  /// Paint background lines.
  final bool paintBackgroundLines;

  /// Fill editing item background.
  final bool fillEditingBackground;

  ///final bool paintItemForeground = false;

  /// Background style
  final EditModeBackgroundStyle backgroundStyle;

  /// Custom resize handle builder that displays a widget in the bottom-right corner
  /// during edit mode. If null, no custom resize handle is shown.
  final ResizeHandleBuilder? resizeHandleBuilder;

  /// Custom delete handle builder that displays a widget in the top-right corner
  /// during edit mode. If null, no custom delete handle is shown.
  final DeleteHandleBuilder? deleteHandleBuilder;
}
