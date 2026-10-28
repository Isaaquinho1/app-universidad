import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays a platform-adaptive button with a filter icon.
class AppSettingsButton extends StatelessWidget {
  /// Creates a button that invokes [onClick] when pressed.
  const AppSettingsButton({
    required this.onClick,
    super.key,
  });

  /// Callback invoked when the button is pressed.
  final VoidCallback onClick;

  @override
  Widget build(BuildContext context) {
    return PlatformIconButton(
      onPressed: onClick,
      icon: Container(
        padding: const EdgeInsets.all(4),
        child: SvgPicture.asset(
          'assets/icons/filter.svg',
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            Theme.of(context).extension<AppColors>()!.active,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
