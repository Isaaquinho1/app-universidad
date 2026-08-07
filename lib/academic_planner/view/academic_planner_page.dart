import 'package:conecta_itt/academic_planner/view/academic_tasks_view.dart';
import 'package:conecta_itt/academic_planner/view/daily_schedule_view.dart';
import 'package:conecta_itt/academic_planner/view/subjects_management_view.dart';
import 'package:conecta_itt/academic_planner/view/weekly_schedule_view.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_planner_section_switch.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AcademicPlannerPage extends StatefulWidget {
  const AcademicPlannerPage({super.key});

  @override
  State<AcademicPlannerPage> createState() => _AcademicPlannerPageState();
}

class _AcademicPlannerPageState extends State<AcademicPlannerPage> {
  static const _tasksIndex = 2;

  int _selectedIndex = 0;
  bool _initialNavigationChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialNavigationChecked) {
      return;
    }

    _initialNavigationChecked = true;

    final state = context.read<AppBloc>().state;

    if (state.pendingAcademicTaskId != null) {
      _openPendingAcademicTask();
    }
  }

  void _openPendingAcademicTask() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_selectedIndex != _tasksIndex) {
        setState(() {
          _selectedIndex = _tasksIndex;
        });
      }

      context.read<AppBloc>().add(const AcademicTaskNavigationConsumed());
    });
  }

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
    return BlocListener<AppBloc, AppState>(
      listenWhen:
          (previous, current) =>
              previous.pendingAcademicTaskId != current.pendingAcademicTaskId &&
              current.pendingAcademicTaskId != null,
      listener: (context, state) {
        _openPendingAcademicTask();
      },
      child: IndexedStack(
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
          _PlannerSectionPage(
            selectedIndex: _selectedIndex,
            onSectionSelected: _selectSection,
            child: const AcademicTasksView(),
          ),
          SubjectsManagementView(
            selectedIndex: _selectedIndex,
            onSectionSelected: _selectSection,
          ),
        ],
      ),
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
