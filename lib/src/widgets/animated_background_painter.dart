part of '../dashboard_base.dart';

class _AnimatedBackgroundPainter extends StatefulWidget {
  const _AnimatedBackgroundPainter(
      {required this.layoutController,
      required this.editModeSettings,
      required this.offset});

  final _DashboardLayoutController layoutController;
  final EditModeSettings editModeSettings;
  final ViewportOffset offset;

  @override
  State<_AnimatedBackgroundPainter> createState() =>
      _AnimatedBackgroundPainterState();
}

class _AnimatedBackgroundPainterState extends State<_AnimatedBackgroundPainter>
    with SingleTickerProviderStateMixin {
  _ViewportDelegate get viewportDelegate =>
      widget.layoutController._viewportDelegate;

  Rect? fillRect;

  late double offset;

  late AnimationController _animationController;

  Animation<Rect?>? _animation;

  @override
  void initState() {
    offset = widget.offset.pixels;
    _animationController = AnimationController(
        vsync: this, duration: widget.editModeSettings.duration);
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Rect? _currentAnimatingRect;
  DateTime? _animationStartTime;

  @override
  Widget build(BuildContext context) {
    offset = widget.offset.pixels; // Update offset once at the beginning

    Rect? newTargetRect;
    if (widget.editModeSettings.fillEditingBackground &&
        widget.layoutController.editSession != null) {
      var pos = widget.layoutController.editSession?.editing._currentPosition(
          viewportDelegate: widget.layoutController._viewportDelegate,
          slotEdge: widget.layoutController.slotEdge,
          verticalSlotEdge: widget.layoutController.verticalSlotEdge);
      newTargetRect = Rect.fromLTWH(
          pos!.x - viewportDelegate.padding.left,
          pos.y - offset - viewportDelegate.padding.top,
          pos.width,
          pos.height);

      if (fillRect != newTargetRect) {
        var beginRect = fillRect ?? newTargetRect;
        Duration animationDuration = widget.editModeSettings.duration;

        if (_animationController.isAnimating && _currentAnimatingRect != null) {
          beginRect = _currentAnimatingRect!;
          if (_animationStartTime != null) {
            final elapsed = DateTime.now().difference(_animationStartTime!);
            final remaining = widget.editModeSettings.duration - elapsed;
            animationDuration = remaining > Duration.zero ? remaining : Duration.zero;
          }
        }
        
        _animationController.duration = animationDuration;
        _animation = RectTween(begin: beginRect, end: newTargetRect).animate(CurvedAnimation(
            parent: _animationController,
            curve: widget.editModeSettings.curve));

        _animationStartTime = DateTime.now();
        // It's generally safer to stop and reset before starting a new animation,
        // especially if the tween or duration changes.
        _animationController.stop(); 
        _animationController.reset(); 

        _animationController.forward().then((_) {
          if (mounted) {
            _animationController.duration = widget.editModeSettings.duration; // Reset to default
            _animationStartTime = null;
            // _currentAnimatingRect is updated by AnimatedBuilder, no need to null here
            // explicitly unless animation is fully done and null.
          }
        });
      }
      fillRect = newTargetRect;
    } else { // Not in edit mode or fill background is disabled
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      fillRect = null;
      _animation = null;
      _currentAnimatingRect = null;
      _animationStartTime = null;
      _animationController.duration = widget.editModeSettings.duration;
    }

    if (_animation != null) {
      return AnimatedBuilder(
          animation: _animation!,
          builder: (context, child) {
            _currentAnimatingRect = _animation!.value; // Keep track of current animated value
            return CustomPaint(
              painter: _EditModeBackgroundPainter(
                  verticalSlotEdge: widget.layoutController.verticalSlotEdge,
                  fillPosition: _animation!.value,
                  slotCount: widget.layoutController.slotCount,
                  style: widget.editModeSettings.backgroundStyle,
                  slotEdge: widget.layoutController.slotEdge,
                  lines: widget.editModeSettings.paintBackgroundLines,
                  offset: offset, // Use the updated offset
                  viewportDelegate: widget.layoutController._viewportDelegate),
              isComplex: true, // Keep isComplex true during active animation
            );
          });
    } else {
      // When not animating, or animation is null
      return CustomPaint(
        painter: _EditModeBackgroundPainter(
            fillPosition: fillRect, // This will be the final target rect or null
            lines: widget.editModeSettings.paintBackgroundLines,
            verticalSlotEdge: widget.layoutController.verticalSlotEdge,
            slotCount: widget.layoutController.slotCount,
            style: widget.editModeSettings.backgroundStyle,
            slotEdge: widget.layoutController.slotEdge,
            offset: offset, // Use the updated offset
            viewportDelegate: widget.layoutController._viewportDelegate),
        // isComplex can be false if not animating, but true is safer if fillRect can change without _animation
        isComplex: widget.editModeSettings.fillEditingBackground && widget.layoutController.editSession != null, 
      );
    }
  }
}
