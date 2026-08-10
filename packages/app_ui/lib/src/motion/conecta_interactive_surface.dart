import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
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
    this.pressedScale = 0.985,
    this.pressedOffset = const Offset(0, 1.5),
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

  @override
  State<ConectaInteractiveSurface> createState() =>
      _ConectaInteractiveSurfaceState();
}

class _ConectaInteractiveSurfaceState extends State<ConectaInteractiveSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) {
      return;
    }

    setState(() {
      _pressed = value;
    });
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
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTap: widget.enabled ? _handleTap : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: ConectaMotion.quick,
        curve: ConectaCurves.emphasized,
        child: AnimatedSlide(
          offset: _pressed
              ? Offset(
                  widget.pressedOffset.dx / 100,
                  widget.pressedOffset.dy / 100,
                )
              : Offset.zero,
          duration: ConectaMotion.quick,
          curve: ConectaCurves.emphasized,
          child: widget.child,
        ),
      ),
    );
  }
}
