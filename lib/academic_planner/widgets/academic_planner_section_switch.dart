import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class AcademicPlannerSectionSwitch extends StatelessWidget {
  const AcademicPlannerSectionSwitch({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConectaSegmentedSelector<int>(
        selectedValue: selectedIndex,
        onChanged: onSelected,
        items: const [
          ConectaSegmentedItem(value: 0, label: 'Día'),
          ConectaSegmentedItem(value: 1, label: 'Tareas'),
          ConectaSegmentedItem(value: 2, label: 'Materias'),
        ],
      ),
    );
  }
}
