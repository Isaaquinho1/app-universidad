import 'package:flutter/material.dart';

class CalendarStoriesAppBar extends StatelessWidget {
  const CalendarStoriesAppBar({
    super.key,
    required this.isStoriesVisible,
    required this.onStoriesLoaded,
  });

  final bool isStoriesVisible;
  final ValueChanged<bool> onStoriesLoaded;

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}
