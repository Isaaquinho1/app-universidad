import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// Ambient background used by premium Conecta ITT experiences.
class ConectaAtmosphere extends StatelessWidget {
  /// Creates a reusable ambient visual layer.
  const ConectaAtmosphere({
    required this.child,
    super.key,
    this.accent,
  });

  /// Foreground content rendered above the atmosphere.
  final Widget child;

  /// Optional contextual accent color.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;
    final resolvedAccent = accent ?? colors.primary;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background01,
        gradient: RadialGradient(
          center: const Alignment(0.65, -0.85),
          radius: 1.35,
          colors: [
            resolvedAccent.withValues(
              alpha: isDark ? 0.13 : 0.075,
            ),
            colors.background01.withValues(alpha: 0),
          ],
          stops: const [0, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      resolvedAccent.withValues(
                        alpha: isDark ? 0.12 : 0.07,
                      ),
                      resolvedAccent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
