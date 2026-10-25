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
    this.scrollWhileEditing = false,
    this.touchPickUpDelay = const Duration(milliseconds: 350),
    this.autoScrollMaxSpeed = 1200,
    this.autoScrollEdge,
    this.pageFlipDwell = const Duration(milliseconds: 500),
  })  : assert(resizeHysteresis >= 0 && resizeHysteresis < 0.5,
            'resizeHysteresis is a fraction of a slot, from 0 to under 0.5'),
        assert(autoScrollMaxSpeed >= 0),
        assert(autoScrollEdge == null || autoScrollEdge > 0),
        duration = duration ?? kThemeAnimationDuration;

  /// Whether the grid keeps scrolling while it is edited.
  ///
  /// `false` (the default) is the behaviour of 1.0.0: in edit mode the grid
  /// does not scroll by hand, every drag on it belongs to the editing gesture,
  /// and it only moves by the auto-scroll of an item dragged to its edge.
  ///
  /// `true`: a drag that starts on an empty slot scrolls the grid (and swipes
  /// the section carousel, see [MobileCarouselConfig.swipeWhileEditing]), and
  /// the mouse wheel scrolls it. An item is picked up:
  ///
  /// * with a mouse, stylus or trackpad, as soon as the pointer moves on it;
  /// * with a finger, after it is held on the item for [touchPickUpDelay]; a
  ///   finger that moves before that scrolls instead;
  /// * on the resize handle ([resizeHandleBuilder]), with any pointer, as soon
  ///   as it moves.
  ///
  /// An item dragged to the top or bottom edge scrolls the grid at up to
  /// [autoScrollMaxSpeed], and in the carousel an item held at a side edge for
  /// [pageFlipDwell] moves to the next section. The grid stays where the drag
  /// took it.
  ///
  /// [panEnabled] and [longPressEnabled] are not consulted, except that with
  /// both `false` items cannot be dragged at all. Dragging an empty slot with
  /// a mouse scrolls only when the dashboard's `scrollBehavior` lists the
  /// mouse in `dragDevices`, which Flutter's default does not.
  final bool scrollWhileEditing;

  /// How long a finger is held on an item before it is picked up, with
  /// [scrollWhileEditing].
  final Duration touchPickUpDelay;

  /// Auto-scroll speed, in logical pixels per second, of an item dragged
  /// right to the edge, with [scrollWhileEditing]. The speed grows from zero
  /// at the inner border of the [autoScrollEdge] zone.
  final double autoScrollMaxSpeed;

  /// Depth of the edge zone that auto-scrolls the grid (and flips the
  /// carousel section), with [scrollWhileEditing].
  ///
  /// `null` means 12% of the viewport's extent, but no less than 40 and no
  /// more than 80 pixels.
  final double? autoScrollEdge;

  /// How long an item is held at a side edge of the section carousel before
  /// the carousel moves to the next section, with [scrollWhileEditing]. Held
  /// there longer, it keeps moving one section at a time.
  final Duration pageFlipDwell;

  /// [autoScrollEdge] resolved for a viewport of [extent] pixels.
  double _edgeFor(double extent) =>
      autoScrollEdge ?? (extent * 0.12).clamp(40.0, 80.0);

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
