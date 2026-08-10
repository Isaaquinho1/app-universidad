import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// Visual treatment applied to a Conecta ITT surface.
enum ConectaSurfaceLevel {
  /// Surface that belongs to the base content plane.
  base,

  /// Standard elevated content surface.
  raised,

  /// Strongly elevated surface used for focused content.
  floating,

  /// Emphasized surface with contextual accent illumination.
  focused,
}

/// Premium reusable surface for the Conecta ITT visual system.
class ConectaSurface extends StatelessWidget {
  /// Creates a Conecta ITT surface.
  const ConectaSurface({
    required this.child,
    super.key,
    this.level = ConectaSurfaceLevel.raised,
    this.accent,
    this.padding,
    this.borderRadius,
    this.onTap,
  });

  /// Content rendered inside the surface.
  final Widget child;

  /// Visual depth assigned to the surface.
  final ConectaSurfaceLevel level;

  /// Optional contextual accent used by focused surfaces.
  final Color? accent;

  /// Internal padding applied to the content.
  final EdgeInsetsGeometry? padding;

  /// Optional radius override.
  final BorderRadiusGeometry? borderRadius;

  /// Optional tap callback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final resolvedAccent = accent ?? colors.primary;

    final shadows = switch (level) {
      ConectaSurfaceLevel.base => ConectaDepth.flat(context),
      ConectaSurfaceLevel.raised => ConectaDepth.raised(context),
      ConectaSurfaceLevel.floating => ConectaDepth.floating(context),
      ConectaSurfaceLevel.focused => ConectaDepth.focused(
          context,
          accent: resolvedAccent,
        ),
    };

    final backgroundColor = switch (level) {
      ConectaSurfaceLevel.base => colors.surface,
      ConectaSurfaceLevel.raised => colors.surfaceHigh,
      ConectaSurfaceLevel.floating => colors.background02,
      ConectaSurfaceLevel.focused => Color.alphaBlend(
          resolvedAccent.withValues(alpha: 0.045),
          colors.surfaceHigh,
        ),
    };

    final resolvedRadius =
        borderRadius ?? BorderRadius.circular(ConectaRadius.card);

    final decoration = BoxDecoration(
      color: backgroundColor,
      borderRadius: resolvedRadius,
      border: Border.all(
        color: level == ConectaSurfaceLevel.focused
            ? resolvedAccent.withValues(alpha: 0.18)
            : colors.borderLight,
      ),
      boxShadow: shadows,
    );

    final content = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: resolvedRadius is BorderRadius ? resolvedRadius : null,
        child: content,
      ),
    );
  }
}
