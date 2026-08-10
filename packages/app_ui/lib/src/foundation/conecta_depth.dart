import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// Corner-radius tokens for the Conecta ITT visual system.
abstract final class ConectaRadius {
  /// Radius for compact interactive controls.
  static const double control = 14;

  /// Default radius for content cards.
  static const double card = 22;

  /// Radius for prominent floating surfaces.
  static const double floating = 28;

  /// Fully rounded radius for pills and indicators.
  static const double pill = 999;
}

/// Elevation and shadow tokens for the Conecta ITT visual system.
abstract final class ConectaDepth {
  /// No elevation. Used when a surface belongs to the base plane.
  static List<BoxShadow> flat(BuildContext context) => const [];

  /// Subtle elevation for standard cards and secondary surfaces.
  static List<BoxShadow> raised(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      BoxShadow(
        color: colors.cardShadowLight,
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ];
  }

  /// Stronger elevation for surfaces floating above surrounding content.
  static List<BoxShadow> floating(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      BoxShadow(
        color: colors.cardShadowDark,
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: colors.cardShadowLight,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Emphasized elevation with a contextual accent glow.
  static List<BoxShadow> focused(
    BuildContext context, {
    required Color accent,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      BoxShadow(
        color: accent.withValues(alpha: 0.16),
        blurRadius: 28,
        spreadRadius: 1,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: colors.cardShadowDark,
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
    ];
  }
}
