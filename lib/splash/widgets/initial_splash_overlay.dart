import 'package:conecta_itt/splash/widgets/institutional_startup_splash.dart';
import 'package:flutter/material.dart';

/// Covers only the first profile load without unmounting the router or listeners.
class InitialSplashOverlay extends StatefulWidget {
  const InitialSplashOverlay({
    required this.ready,
    required this.child,
    super.key,
  });

  final bool ready;
  final Widget child;

  @override
  State<InitialSplashOverlay> createState() => _InitialSplashOverlayState();
}

class _InitialSplashOverlayState extends State<InitialSplashOverlay> {
  late bool _finished = widget.ready;

  @override
  void didUpdateWidget(covariant InitialSplashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _finished = _finished || widget.ready;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep the route and notification listeners alive behind the splash.
        IgnorePointer(
          ignoring: !_finished,
          child: ExcludeFocus(
            excluding: !_finished,
            child: ExcludeSemantics(excluding: !_finished, child: widget.child),
          ),
        ),
        if (!_finished)
          const Positioned.fill(child: InstitutionalStartupSplash()),
      ],
    );
  }
}
