import 'package:conecta_itt/academic_planner/view/daily_schedule_view.dart';
import 'package:conecta_itt/academic_planner/view/subjects_management_view.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_planner_section_switch.dart';
import 'package:flutter/material.dart';

class AcademicPlannerPage extends StatefulWidget {
  const AcademicPlannerPage({super.key});

  @override
  State<AcademicPlannerPage> createState() => _AcademicPlannerPageState();
}

class _AcademicPlannerPageState extends State<AcademicPlannerPage> {
  int _selectedIndex = 0;

  void _selectSection(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _DailySchedulePage(
          selectedIndex: _selectedIndex,
          onSectionSelected: _selectSection,
        ),
        SubjectsManagementView(
          selectedIndex: _selectedIndex,
          onSectionSelected: _selectSection,
        ),
      ],
    );
  }
}

class _DailySchedulePage extends StatelessWidget {
  const _DailySchedulePage({
    required this.selectedIndex,
    required this.onSectionSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horario'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: AcademicPlannerSectionSwitch(
            selectedIndex: selectedIndex,
            onSelected: onSectionSelected,
          ),
        ),
      ),
      body: const SafeArea(bottom: false, child: DailyScheduleView()),
    );
  }
}
