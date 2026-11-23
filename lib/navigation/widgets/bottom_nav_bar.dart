import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/repositories/admin_profile_photo_repository.dart';
import 'package:conecta_itt/institutional_profile/services/profile_photo_review_badge_controller.dart';
import 'package:conecta_itt/institutional_profile/repositories/student_profile_photo_repository.dart';
import 'package:conecta_itt/institutional_profile/services/student_photo_approval_badge_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:conecta_itt/navigation/view/scaffold_navigation_shell.dart';

/// Animates the bottom navigation bar to slide up/down based on scroll direction
class AnimatedBottomNavigationBar extends StatefulWidget {
  const AnimatedBottomNavigationBar({
    super.key,
    required this.index,
    required this.onClick,
  });

  final Function(int) onClick;
  final int index;

  @override
  State<AnimatedBottomNavigationBar> createState() =>
      _AnimatedBottomNavigationBarState();
}

class _AnimatedBottomNavigationBarState
    extends State<AnimatedBottomNavigationBar> {
  final _controller = BottomNavigationBarVisibilityController.instance;
  late final VoidCallback _visibilityListener;

  @override
  void initState() {
    super.initState();
    _visibilityListener = () {
      if (mounted) setState(() {});
    };
    _controller.addListener(_visibilityListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final profile = context.watch<AppBloc>().state.institutionalProfile;

    final badge = ProfilePhotoReviewBadgeController.instance;

    if (profile != null && profile.canReviewProfilePhotos) {
      badge.bind(
        userId: profile.uid,
        repository: context.read<AdminProfilePhotoRepository>(),
      );
    } else {
      badge.unbind();
    }

    final studentBadge = StudentPhotoApprovalBadgeController.instance;

    if (profile != null && profile.isStudent) {
      studentBadge.bind(
        userId: profile.uid,
        repository: context.read<StudentProfilePhotoRepository>(),
      );
    } else {
      studentBadge.unbind();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_visibilityListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final controlledBottomInset =
        mediaQuery.viewPadding.bottom > 0
            ? mediaQuery.viewPadding.bottom * 0.35
            : 0.0;

    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: controlledBottomInset),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          offset: Offset(0, _controller.isVisible ? 0 : 1),
          child: AppBottomNavigationBar(
            key: ValueKey<int>(widget.index),
            index: widget.index,
            onClick: widget.onClick,
          ),
        ),
      ),
    );
  }
}

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.index,
    required this.onClick,
  });

  final int index;
  final ValueChanged<int> onClick;

  static const _blue = Color(0xFF2864FF);
  static const _dark = Color(0xFF17223A);

  static const _labels = ['Publicaciones', 'Horario', 'Servicios', 'Perfil'];

  static const _icons = [
    Icons.article_outlined,
    Icons.calendar_month_outlined,
    Icons.grid_view_rounded,
    Icons.account_circle_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark
            ? (theme.extension<AppColors>()?.surfaceHigh ??
                theme.colorScheme.surfaceContainerHigh)
            : const Color(0xFFFCFCFE);
    final inactiveColor = isDark ? theme.colorScheme.onSurface : _dark;

    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? surfaceColor : const Color(0xFFECEFF4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.075),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(4, (i) {
          final selected = index == i;

          return Expanded(
            child: Semantics(
              label: _labels[i],
              selected: selected,
              button: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onClick(i);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 30,
                        child: ValueListenableBuilder<bool>(
                          valueListenable:
                              StudentPhotoApprovalBadgeController
                                  .instance
                                  .hasUnseenApproval,
                          builder: (context, studentUnseen, _) {
                            return ValueListenableBuilder<int>(
                              valueListenable:
                                  ProfilePhotoReviewBadgeController
                                      .instance
                                      .unseenCount,
                              builder: (context, count, _) {
                                return Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      _icons[i],
                                      size: 23,
                                      color: selected ? _blue : inactiveColor,
                                    ),

                                    // Existing administrative counter.
                                    if (i == 2 && count > 0)
                                      Positioned(
                                        top: -5,
                                        right: -3,
                                        child: Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                          child: Text(
                                            count > 99 ? '99+' : '$count',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              height: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Student: approved photo not yet viewed.
                                    if (i == 3 && studentUnseen)
                                      Positioned(
                                        top: -2,
                                        right: 3,
                                        child: Container(
                                          width: 11,
                                          height: 11,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: surfaceColor,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _labels[i],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? _blue : inactiveColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? _blue : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
