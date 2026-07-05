import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A customizable back button widget that adapts to different themes.
class AppBackButton extends StatelessWidget {
  /// Creates a default [AppBackButton] with dark icon suitable for light backgrounds.
  const AppBackButton({
    required this.onPressed,
    super.key,
    this.icon = Icons.arrow_back,
    this.iconColor,
  });

  /// Creates a light variant of [AppBackButton] with white icon suitable for dark backgrounds.
  const AppBackButton.light({
    required this.onPressed,
    super.key,
    this.icon = Icons.arrow_back,
  }) : iconColor = Colors.white;

  /// The callback that is called when the button is tapped.
  final VoidCallback onPressed;

  /// The icon to display in the button.
  final dynamic icon;

  /// The color of the icon. If null, uses theme colors.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final resolvedColor = iconColor ?? colors.active;

    return IconButton(
      onPressed: onPressed,
      icon: icon is IconData
          ? Icon(
              icon as IconData,
              color: resolvedColor,
            )
          : HugeIcon(
              icon: icon as List<List<dynamic>>,
              color: resolvedColor,
            ),
      splashRadius: 20,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}
