import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Interactive wrapper that gives Conecta ITT surfaces a physical response.
class ConectaInteractiveSurface extends StatefulWidget {
  /// Creates an interactive motion surface.
  const ConectaInteractiveSurface({
    required this.child,
    super.key,
    this.onTap,
    this.enabled = true,
    this.haptics = true,
    this.pressedScale = 0.978,
    this.pressedOffset = const Offset(0, 2),
    this.restingScale = 1,
    this.restingOffset = Offset.zero,
  });

  /// Content rendered inside the interactive surface.
  final Widget child;

  /// Action executed when the surface is tapped.
  final VoidCallback? onTap;

  /// Whether the interaction is enabled.
  final bool enabled;

  /// Whether subtle haptic feedback is emitted on tap.
  final bool haptics;

  /// Scale applied while the pointer is pressing the surface.
  final double pressedScale;

  /// Translation applied while the pointer is pressing the surface.
  final Offset pressedOffset;

  /// Scale used while the surface is resting.
  final double restingScale;

  /// Translation used while the surface is resting.
  final Offset restingOffset;

  @override
  State<ConectaInteractiveSurface> createState() =>
      _ConectaInteractiveSurfaceState();
}

class _ConectaInteractiveSurfaceState extends State<ConectaInteractiveSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  late Animation<Offset> _offset;

  bool _pressed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController.unbounded(
      vsync: this,
    );

    _configureAnimations();
  }

  @override
  void didUpdateWidget(ConectaInteractiveSurface oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pressedScale != widget.pressedScale ||
        oldWidget.pressedOffset != widget.pressedOffset ||
        oldWidget.restingScale != widget.restingScale ||
        oldWidget.restingOffset != widget.restingOffset) {
      _configureAnimations();
    }
  }

  void _configureAnimations() {
    _scale = Tween<double>(
      begin: widget.restingScale,
      end: widget.pressedScale,
    ).animate(_controller);

    _offset = Tween<Offset>(
      begin: widget.restingOffset,
      end: widget.pressedOffset,
    ).animate(_controller);
  }

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) {
      return;
    }

    _pressed = value;

    final simulation = SpringSimulation(
      ConectaSpring.responsive,
      _controller.value,
      value ? 1 : 0,
      0,
    );

    _controller.animateWith(simulation);
  }

  void _handleTap() {
    if (!widget.enabled) {
      return;
    }

    if (widget.haptics) {
      HapticFeedback.lightImpact();
    }

    widget.onTap?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTap: widget.enabled ? _handleTap : null,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final offset = _offset.value;

          return Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
