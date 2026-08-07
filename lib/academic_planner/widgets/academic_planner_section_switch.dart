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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<int>(
              value: 0,
              icon: Icon(Icons.today_rounded),
              label: Text('Día'),
            ),
            ButtonSegment<int>(
              value: 1,
              icon: Icon(Icons.calendar_view_week_rounded),
              label: Text('Semana'),
            ),
            ButtonSegment<int>(
              value: 2,
              icon: Icon(Icons.menu_book_rounded),
              label: Text('Materias'),
            ),
          ],
          selected: {selectedIndex},
          onSelectionChanged: (selection) {
            onSelected(selection.first);
          },
        ),
      ),
    );
  }
}
