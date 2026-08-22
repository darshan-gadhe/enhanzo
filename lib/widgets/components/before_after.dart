import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../demo_image.dart';

/// How a [BeforeAfterSlider]'s divider can be moved.
enum BeforeAfterDrag {
  /// Drag anywhere on the image; a tap sends the divider to that point.
  ///
  /// Grabbing near the divider scrubs it relative to the finger; grabbing far
  /// from it moves it to the finger first, then scrubs. Not for use inside a
  /// horizontally scrolling parent — it would swallow every swipe.
  surface,

  /// Only the handle accepts drags, so a horizontally scrolling parent (the
  /// home carousel) keeps its own swipes.
  handle,

  /// Static split at the current position: no drag, no handle.
  none,
}

/// The app's single before/after comparison.
///
/// Renders [after] full-bleed with [before] clipped to the left of a divider
/// the user can move. Every comparison in the app — the home carousel, the
/// tool cards, the edit result, the paywall hero — is this widget with
/// different knobs, so the divider, the handle and the origin tags can never
/// drift apart between screens.
///
/// **Movement is relative, not absolute.** Dragging moves the divider by how
/// far the finger travelled rather than snapping it under the finger, so
/// grabbing the handle anywhere on its 44pt target doesn't jolt the divider to
/// the touch point. Taps (in [BeforeAfterDrag.surface] mode) animate the
/// divider across instead of cutting to it.
///
/// Uncontrolled by default: the position lives here, starting at
/// [initialPosition]. Pass [position] to drive it from outside — then
/// [onChanged] is the only way it moves.
class BeforeAfterSlider extends StatefulWidget {
  final Widget before;
  final Widget after;

  /// Externally controlled divider position, 0..1. Null => uncontrolled.
  final double? position;

  /// Fires on every change, in both modes. Required when [position] is set.
  final ValueChanged<double>? onChanged;

  /// Where an uncontrolled divider starts, 0..1.
  final double initialPosition;

  /// Which gestures move the divider.
  final BeforeAfterDrag drag;

  /// In [BeforeAfterDrag.surface] mode, whether a tap glides the divider to the
  /// touch point. On a card whose whole surface also launches the tool this is
  /// set false, so a tap opens the tool and only a horizontal drag scrubs —
  /// the divider is still grabbable from either side, it just isn't moved by a
  /// plain tap. Ignored in the other drag modes.
  final bool tapToSeek;

  /// Sweep the divider once on mount so users notice it's interactive. Ignored
  /// when controlled or when the platform asks for reduced motion.
  final bool introSweep;

  /// The BEFORE / AFTER origin tags in the top corners.
  final bool showLabels;
  final String beforeLabel;
  final String afterLabel;

  /// Draws the round grab handle on the divider. Defaults to on whenever the
  /// comparison is interactive.
  final bool? showHandle;

  /// Handle diameter. The tap target around it is always at least
  /// [AppSizing.minTapTarget] wide regardless of this.
  final double handleSize;

  /// Colour of the divider line and the handle fill. Defaults to white, which
  /// reads over imagery in either theme.
  final Color lineColor;

  /// Rounds and clips the whole comparison. Null when the parent already clips
  /// (an [AppCard] with `clip: true`, a [ClipRRect]).
  final BorderRadius? borderRadius;

  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.position,
    this.onChanged,
    this.initialPosition = 0.5,
    this.drag = BeforeAfterDrag.surface,
    this.tapToSeek = true,
    this.introSweep = false,
    this.showLabels = true,
    this.beforeLabel = 'BEFORE',
    this.afterLabel = 'AFTER',
    this.showHandle,
    this.handleSize = AppSizing.compareHandle,
    this.lineColor = AppColors.onColor,
    this.borderRadius,
  }) : assert(
         position == null || onChanged != null,
         'A controlled BeforeAfterSlider needs onChanged to move.',
       );

  /// Comparison of one subject in its two variants — real tool photography when
  /// [art] is given (see [DemoImage.art]), otherwise the procedural [scene].
  BeforeAfterSlider.scene(
    DemoScene scene, {
    super.key,
    int seed = 7,
    String? art,
    this.position,
    this.onChanged,
    this.initialPosition = 0.5,
    this.drag = BeforeAfterDrag.surface,
    this.tapToSeek = true,
    this.introSweep = false,
    this.showLabels = true,
    this.beforeLabel = 'BEFORE',
    this.afterLabel = 'AFTER',
    this.showHandle,
    this.handleSize = AppSizing.compareHandle,
    this.lineColor = AppColors.onColor,
    this.borderRadius,
  }) : before = DemoImage(
         scene: scene,
         variant: DemoVariant.before,
         seed: seed,
         art: art,
       ),
       after = DemoImage(
         scene: scene,
         variant: DemoVariant.after,
         seed: seed,
         art: art,
       ),
       assert(
         position == null || onChanged != null,
         'A controlled BeforeAfterSlider needs onChanged to move.',
       );

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider>
    with SingleTickerProviderStateMixin {
  /// Travel limits. The divider never reaches an edge, so neither side of the
  /// comparison can disappear entirely — there is always something to drag
  /// back.
  static const double _min = 0.04;
  static const double _max = 0.96;

  /// How close to the divider a surface touch counts as grabbing it (rather
  /// than asking the divider to come to the finger).
  static const double _grabRadius = 32;

  /// One press of the screen-reader's increase/decrease action.
  static const double _a11yStep = 0.1;

  /// How much the handle grows while it is being dragged.
  static const double _handlePressScale = 1.12;

  /// Delay before the intro sweep runs, so the card has settled first.
  static const Duration _introDelay = Duration(milliseconds: 350);

  late double _pos = widget.initialPosition.clamp(_min, _max);
  // Created eagerly in initState — not as a `late final` initializer. A lazy
  // initializer defers creation to first use; a slider that is disposed before
  // it ever animates (every static or controlled instance) would hit that first
  // use inside dispose(), where the ticker's TickerMode lookup runs against a
  // deactivated element and throws "Looking up a deactivated widget's ancestor".
  late final AnimationController _anim;
  Animation<double>? _drive;
  Timer? _introTimer;

  /// Divider position the current drag started from, advanced by finger deltas.
  double _dragPos = 0;
  bool _dragging = false;

  bool get _controlled => widget.position != null;
  bool get _interactive => widget.drag != BeforeAfterDrag.none;
  bool get _showHandle => widget.showHandle ?? _interactive;
  double get _value => (_controlled ? widget.position! : _pos).clamp(_min, _max);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: AppDurations.quick)
      ..addListener(_onAnimTick);
    if (widget.introSweep && !_controlled) {
      _pos = 0.82;
      _introTimer = Timer(_introDelay, _runIntroSweep);
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  /// One-shot hint that the divider moves: out, back past centre, then settle.
  void _runIntroSweep() {
    if (!mounted || !context.motionEnabled) return;
    _anim.duration = AppDurations.sweep;
    _drive = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.82, end: 0.30)
            .chain(CurveTween(curve: AppDurations.emphasized)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.30, end: 0.50)
            .chain(CurveTween(curve: AppDurations.easeOutCubic)),
        weight: 40,
      ),
    ]).animate(_anim);
    _anim
      ..reset()
      ..forward();
  }

  void _onAnimTick() {
    final drive = _drive;
    if (drive != null) _emit(drive.value);
  }

  /// Publishes a new position — to the parent when controlled, to local state
  /// otherwise.
  void _emit(double next) {
    final value = next.clamp(_min, _max);
    if (_controlled) {
      if (value != widget.position) widget.onChanged?.call(value);
    } else {
      if (value == _pos) return;
      setState(() => _pos = value);
      widget.onChanged?.call(value);
    }
  }

  void _stopAnimating() {
    _introTimer?.cancel();
    if (_anim.isAnimating) _anim.stop();
  }

  void _animateTo(double target) {
    _stopAnimating();
    final to = target.clamp(_min, _max);
    if (!context.motionEnabled) {
      _emit(to);
      return;
    }
    _anim.duration = AppDurations.quick;
    _drive = Tween<double>(begin: _value, end: to)
        .animate(CurvedAnimation(parent: _anim, curve: AppDurations.easeOut));
    _anim
      ..reset()
      ..forward();
  }

  /// [grabbed] is true when the gesture began on the handle, where the divider
  /// must not jump; a touch out on the image brings the divider over first.
  void _onDragStart(double localX, double width, {required bool grabbed}) {
    _stopAnimating();
    if (grabbed || width <= 0) {
      _dragPos = _value;
    } else {
      _dragPos = (localX / width).clamp(_min, _max);
      _emit(_dragPos);
    }
    AppHaptics.tick();
    setState(() => _dragging = true);
  }

  void _onDragUpdate(double dx, double width) {
    if (width <= 0) return;
    _dragPos = (_dragPos + dx / width).clamp(_min, _max);
    _emit(_dragPos);
  }

  void _onDragEnd() {
    if (!_dragging) return;
    setState(() => _dragging = false);
  }

  /// Whether a surface touch at [localX] landed on the divider itself.
  bool _isOnHandle(double localX, double width) =>
      (localX - _value * width).abs() <= _grabRadius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pos = _value;
        final x = width * pos;
        final handleMode = widget.drag == BeforeAfterDrag.handle;
        // The handle needs a target of its own only when it is the sole drag
        // surface; otherwise the whole image already listens and an inner
        // detector would just steal taps from it.
        final tapWidth = handleMode
            ? AppSizing.minTapTarget
            : widget.handleSize;

        Widget comparison = Stack(
          fit: StackFit.expand,
          children: [
            widget.after,
            ClipRect(clipper: _LeftClipper(pos), child: widget.before),
            if (widget.showLabels) ...[
              _CompareTag.positioned(
                text: widget.beforeLabel,
                align: Alignment.topLeft,
                // Each tag hides once the divider crosses it, so it never
                // labels a side that is no longer there.
                visible: pos > 0.16,
                background: AppOverlay.scrimTag,
                foreground: AppColors.onColor,
              ),
              _CompareTag.positioned(
                text: widget.afterLabel,
                align: Alignment.topRight,
                visible: pos < 0.84,
                background: AppColors.onColor,
                foreground: AppOverlay.ink,
              ),
            ],
            Positioned(
              left: x - AppSizing.strokeThin / 2,
              top: 0,
              bottom: 0,
              child: _CompareDivider(color: widget.lineColor),
            ),
            if (_showHandle)
              Positioned(
                left: x - tapWidth / 2,
                top: 0,
                bottom: 0,
                width: tapWidth,
                child: IgnorePointer(
                  // Only the handle-only mode wires gestures here; in surface
                  // mode the whole image is the target and this must let taps
                  // through to it.
                  ignoring: !handleMode,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) =>
                        _onDragStart(0, width, grabbed: true),
                    onHorizontalDragUpdate: (d) =>
                        _onDragUpdate(d.delta.dx, width),
                    onHorizontalDragEnd: (_) => _onDragEnd(),
                    onHorizontalDragCancel: _onDragEnd,
                    child: Center(
                      child: _CompareHandle(
                        size: widget.handleSize,
                        color: widget.lineColor,
                        scale: _dragging ? _handlePressScale : 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        if (widget.drag == BeforeAfterDrag.surface) {
          comparison = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => _onDragStart(
              d.localPosition.dx,
              width,
              grabbed: _isOnHandle(d.localPosition.dx, width),
            ),
            onHorizontalDragUpdate: (d) => _onDragUpdate(d.delta.dx, width),
            onHorizontalDragEnd: (_) => _onDragEnd(),
            onHorizontalDragCancel: _onDragEnd,
            // A tap is a request to see that much of the other side; it glides
            // there rather than cutting, so the eye can follow the seam. Left
            // unwired when the surface has a tap job of its own (a card that
            // launches on tap), so a plain tap passes through to that instead.
            onTapUp: widget.tapToSeek
                ? (d) => _animateTo(d.localPosition.dx / width)
                : null,
            child: comparison,
          );
        }

        if (widget.borderRadius != null) {
          comparison = ClipRRect(
            borderRadius: widget.borderRadius!,
            child: comparison,
          );
        }

        if (!_interactive) return ExcludeSemantics(child: comparison);

        // Announced and operable as a slider: a screen-reader user can move
        // the divider in steps without being able to drag it. A node that
        // exposes increase/decrease actions must also state what value each
        // would land on, so the framework announces the change — hence the
        // paired increased/decreased values, not just the current one.
        final label = widget.beforeLabel.toLowerCase();
        String pctLabel(double p) => '${(p.clamp(0.0, 1.0) * 100).round()}% $label';
        return Semantics(
          slider: true,
          label: '${widget.beforeLabel} and ${widget.afterLabel} comparison',
          value: pctLabel(pos),
          increasedValue: pctLabel(pos + _a11yStep),
          decreasedValue: pctLabel(pos - _a11yStep),
          onIncrease: () => _animateTo(pos + _a11yStep),
          onDecrease: () => _animateTo(pos - _a11yStep),
          child: ExcludeSemantics(child: comparison),
        );
      },
    );
  }
}

/// The seam between the two sides.
///
/// Full white with a hairline shadow so it reads over a bright half (a pale
/// sky, a washed-out original) as clearly as over a dark one, rather than
/// dissolving into it. A null-child Container stretches to the full height
/// under the loose constraints [Center] hands down.
class _CompareDivider extends StatelessWidget {
  final Color color;

  const _CompareDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizing.strokeThin,
      decoration: BoxDecoration(color: color, boxShadow: AppShadows.hairline),
    );
  }
}

/// The round grab affordance on the divider.
///
/// Its glyph points **left and right** — the axis the divider actually travels
/// on. It used to be the vertical `unfold_more` pair, which pointed up and
/// down and so described a gesture this control does not accept.
class _CompareHandle extends StatelessWidget {
  final double size;
  final Color color;
  final double scale;

  const _CompareHandle({
    required this.size,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      duration: context.motion(AppDurations.fast),
      curve: AppDurations.easeOut,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          // Lifts the handle off whatever photo sits under it.
          boxShadow: AppShadows.floating,
        ),
        child: const Icon(
          AppIcons.compare,
          color: AppOverlay.ink,
          size: AppSizing.iconMd,
        ),
      ),
    );
  }
}

/// Tiny uppercase origin tag ("BEFORE" / "AFTER") pinned to a top corner.
class _CompareTag extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final bool visible;

  const _CompareTag({
    required this.text,
    required this.background,
    required this.foreground,
    this.visible = true,
  });

  /// The tag already placed in a [Stack] corner, fading with [visible].
  static Widget positioned({
    required String text,
    required Alignment align,
    required Color background,
    required Color foreground,
    bool visible = true,
    double inset = AppSpacing.x12,
  }) {
    return Positioned(
      top: inset,
      left: align.x < 0 ? inset : null,
      right: align.x > 0 ? inset : null,
      child: _CompareTag(
        text: text,
        background: background,
        foreground: foreground,
        visible: visible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: context.motion(AppDurations.quick),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8,
          vertical: AppSpacing.x4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.brPill,
        ),
        child: Text(text, style: AppText.tag(foreground)),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  final double fraction;
  const _LeftClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.fraction != fraction;
}
