import 'package:flutter/animation.dart';

/// Motion duration tokens used throughout Conecta ITT.
abstract final class ConectaMotion {
  /// Near-instant feedback for immediate UI reactions.
  static const Duration instant = Duration(milliseconds: 100);

  /// Quick feedback for taps and small state changes.
  static const Duration quick = Duration(milliseconds: 180);

  /// Default duration for standard interface transitions.
  static const Duration standard = Duration(milliseconds: 280);

  /// Duration for transitions that require stronger visual emphasis.
  static const Duration emphasized = Duration(milliseconds: 420);

  /// Duration for staged entrance animations.
  static const Duration entrance = Duration(milliseconds: 520);

  /// Duration reserved for spatial shared-element transitions.
  static const Duration sharedTransition = Duration(milliseconds: 620);
}

/// Motion curves used throughout Conecta ITT.
abstract final class ConectaCurves {
  /// General-purpose interface movement.
  static const Curve standard = Curves.easeOutCubic;

  /// Stronger spatial movement such as expanding cards.
  static const Curve emphasized = Curves.easeOutQuart;

  /// Curve used by elements leaving the current visual context.
  static const Curve exit = Curves.easeInCubic;

  /// Smooth curve when entrance and exit are equally important.
  static const Curve spatial = Curves.easeInOutCubic;
}

/// Spring configurations for physically responsive interactions.
abstract final class ConectaSpring {
  /// Soft response for subtle interface feedback.
  static const SpringDescription gentle = SpringDescription(
    mass: 1,
    stiffness: 170,
    damping: 22,
  );

  /// Default spring for interactive cards, controls and selectors.
  static const SpringDescription responsive = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 24,
  );

  /// Expressive response reserved for emphasized interactions.
  static const SpringDescription expressive = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 21,
  );
}
