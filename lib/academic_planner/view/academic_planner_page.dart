import 'package:conecta_itt/academic_planner/view/daily_schedule_view.dart';
import 'package:conecta_itt/academic_planner/view/subjects_management_view.dart';
import 'package:conecta_itt/academic_planner/view/weekly_schedule_view.dart';
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
        _PlannerSectionPage(
          selectedIndex: _selectedIndex,
          onSectionSelected: _selectSection,
          child: const DailyScheduleView(),
        ),
        _PlannerSectionPage(
          selectedIndex: _selectedIndex,
          onSectionSelected: _selectSection,
          child: const WeeklyScheduleView(),
        ),
        SubjectsManagementView(
          selectedIndex: _selectedIndex,
          onSectionSelected: _selectSection,
        ),
      ],
    );
  }
}

class _PlannerSectionPage extends StatelessWidget {
  const _PlannerSectionPage({
    required this.selectedIndex,
    required this.onSectionSelected,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onSectionSelected;
  final Widget child;

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
      body: SafeArea(bottom: false, child: child),
    );
  }
}
