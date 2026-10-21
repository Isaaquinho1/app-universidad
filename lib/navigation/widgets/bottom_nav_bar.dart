import 'package:flutter/material.dart';
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
    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFE),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFECEFF4)),
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
                      Icon(
                        _icons[i],
                        size: 23,
                        color: selected ? _blue : _dark,
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
                            color: selected ? _blue : _dark,
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
