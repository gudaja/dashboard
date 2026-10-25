part of '../dashboard_base.dart';

/// What a pointer went down on, for [_EditDragGestureRecognizer].
enum _EditHit {
  /// An empty slot, or the gap around an item: the recognizer stays out of the
  /// arena, and the drag of the `Scrollable` or of the carousel has it.
  none,

  /// An item, away from its resize handle.
  tile,

  /// The resize handle of an item ([EditModeSettings.resizeHandleBuilder]).
  handle,
}

/// The edit-mode drag of a grid with [EditModeSettings.scrollWhileEditing].
///
/// Unlike the pan of a `GestureDetector`, it decides on `down` whether it
/// takes part at all: over an empty slot it does not, so the vertical drag of
/// the `Scrollable` and the horizontal drag of the carousel win without a
/// fight. Over an item:
///
/// * a finger picks it up after [touchPickUpDelay]; moving past the touch slop
///   before that gives the gesture up, and the scroll or the swipe takes it —
///   the arbitration of `ReorderableListView`, done by the arena;
/// * a mouse, stylus or trackpad picks it up on its first move, and so does
///   any pointer on the resize handle. Not on `down`: a tap on a handle the
///   consumer draws on the item (the delete handle) has to reach that handle.
///   The first move is enough to beat the carousel, whose horizontal drag
///   needs a longer one: this recognizer sits deeper in the hit test, so it
///   routes every move event before the carousel's does.
///
/// [onStart] gets the position of the `down`, so the item and the edges are
/// picked where the pointer went down, as with `DragStartBehavior.down`.
class _EditDragGestureRecognizer extends OneSequenceGestureRecognizer {
  _EditDragGestureRecognizer({super.debugOwner});

  late _EditHit Function(Offset local) hitTest;
  late Duration touchPickUpDelay;
  late void Function(Offset local, Offset global) onStart;
  late void Function(Offset local, Offset global) onUpdate;
  late VoidCallback onEnd;

  int? _pointer;
  bool _waitsForHold = false;
  bool _started = false;
  Offset _downLocal = Offset.zero;
  Offset _downGlobal = Offset.zero;
  Timer? _holdTimer;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null &&
      super.isPointerAllowed(event) &&
      hitTest(event.localPosition) != _EditHit.none;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _pointer = event.pointer;
    _downLocal = event.localPosition;
    _downGlobal = event.position;
    _waitsForHold = event.kind == PointerDeviceKind.touch &&
        hitTest(event.localPosition) == _EditHit.tile;
    if (_waitsForHold) {
      _holdTimer = Timer(touchPickUpDelay, () {
        _holdTimer = null;
        HapticFeedback.selectionClick();
        _start(_downLocal, _downGlobal);
      });
    }
  }

  void _start(Offset local, Offset global) {
    _started = true;
    resolve(GestureDisposition.accepted);
    onStart(_downLocal, _downGlobal);
    if (local != _downLocal) {
      onUpdate(local, global);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      if (_started) {
        onUpdate(event.localPosition, event.position);
      } else {
        final moved = (event.position - _downGlobal).distance;
        if (_waitsForHold) {
          if (moved > computeHitSlop(event.kind, gestureSettings)) {
            resolve(GestureDisposition.rejected);
            stopTrackingPointer(event.pointer);
          }
        } else if (moved > kPrecisePointerHitSlop) {
          _start(event.localPosition, event.position);
        }
      }
    } else if (!_started &&
        (event is PointerUpEvent || event is PointerCancelEvent)) {
      // Before the arena's sweep on `up`: a pointer that never moved leaves
      // the arena to a tap on a handle.
      resolve(GestureDisposition.rejected);
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointer = null;
    if (_started) {
      _started = false;
      onEnd();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _holdTimer = null;
    super.dispose();
  }

  @override
  String get debugDescription => 'edit drag';
}
