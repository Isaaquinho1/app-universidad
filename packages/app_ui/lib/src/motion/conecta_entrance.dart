import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// Entrance animation for Conecta ITT content.
class ConectaEntrance extends StatelessWidget {
  /// Creates an animated entrance wrapper.
  const ConectaEntrance({
    required this.child,
    super.key,
    this.index = 0,
    this.offset = const Offset(0, 0.04),
    this.enabled = true,
  });

  /// Content rendered by the entrance animation.
  final Widget child;

  /// Position in a staggered sequence.
  final int index;

  /// Initial normalized slide offset.
  final Offset offset;

  /// Whether the entrance animation is enabled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    final delay = Duration(milliseconds: 55 * index);

    return _DelayedEntrance(
      delay: delay,
      offset: offset,
      child: child,
    );
  }
}

class _DelayedEntrance extends StatefulWidget {
  const _DelayedEntrance({
    required this.delay,
    required this.offset,
    required this.child,
  });

  final Duration delay;
  final Offset offset;
  final Widget child;

  @override
  State<_DelayedEntrance> createState() => _DelayedEntranceState();
}

class _DelayedEntranceState extends State<_DelayedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: ConectaMotion.entrance,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: ConectaCurves.standard,
    );

    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: ConectaCurves.emphasized,
      ),
    );

    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
