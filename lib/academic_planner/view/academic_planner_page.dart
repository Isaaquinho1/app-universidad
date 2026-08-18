import 'package:conecta_itt/academic_planner/view/academic_tasks_view.dart';
import 'package:conecta_itt/academic_planner/view/subject_sessions_page.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subject_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_task_repository.dart';
import 'package:conecta_itt/academic_planner/view/daily_schedule_view.dart';
import 'package:conecta_itt/academic_planner/view/subjects_management_view.dart';
import 'package:conecta_itt/academic_planner/view/weekly_schedule_view.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_planner_section_switch.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/academic_planner/view/academic_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AcademicPlannerPage extends StatefulWidget {
  const AcademicPlannerPage({super.key});

  @override
  State<AcademicPlannerPage> createState() => _AcademicPlannerPageState();
}

class _AcademicPlannerPageState extends State<AcademicPlannerPage> {
  static const _tasksIndex = 2;
  static const _subjectsIndex = 3;

  final AcademicSubjectRepository _subjectRepository =
      AcademicSubjectRepository();

  final AcademicTaskRepository _taskRepository = AcademicTaskRepository();

  int _selectedIndex = 0;
  bool _initialNavigationChecked = false;
  AcademicTaskEditLauncher? _academicTaskEditLauncher;

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
      return;
    }

    if (state.pendingClassSessionId != null &&
        state.pendingClassSubjectId != null) {
      _openPendingClassSession();
    }
  }

  void _openPendingAcademicTask() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final appBloc = context.read<AppBloc>();
      final taskId = appBloc.state.pendingAcademicTaskId;

      if (taskId == null || taskId.isEmpty) {
        return;
      }

      if (_selectedIndex != _tasksIndex) {
        setState(() {
          _selectedIndex = _tasksIndex;
        });
      }

      final task = await _taskRepository.getById(taskId);

      if (!mounted) {
        return;
      }

      if (task == null) {
        appBloc.add(const AcademicTaskNavigationConsumed());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La tarea ya no está disponible.')),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder:
              (_) => AcademicTaskDetailPage(
                taskId: task.id,
                onEdit: (task, subjects, categories) async {
                  final launcher = _academicTaskEditLauncher;

                  if (launcher == null) {
                    if (!mounted) {
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'La edición todavía no está disponible. '
                          'Intenta nuevamente.',
                        ),
                      ),
                    );
                    return;
                  }

                  await launcher(task, subjects, categories);
                },
              ),
        ),
      );

      if (!mounted) {
        return;
      }

      appBloc.add(const AcademicTaskNavigationConsumed());
    });
  }

  void _openPendingClassSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final appBloc = context.read<AppBloc>();
      final state = appBloc.state;

      final subjectId = state.pendingClassSubjectId;
      final sessionId = state.pendingClassSessionId;

      if (subjectId == null ||
          subjectId.isEmpty ||
          sessionId == null ||
          sessionId.isEmpty) {
        return;
      }

      if (_selectedIndex != _subjectsIndex) {
        setState(() {
          _selectedIndex = _subjectsIndex;
        });
      }

      final subject = await _subjectRepository.getById(subjectId);

      if (!mounted) {
        return;
      }

      if (subject == null) {
        appBloc.add(const ClassSessionNavigationConsumed());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La materia asociada a este recordatorio ya no está disponible.',
            ),
          ),
        );

        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => SubjectSessionsPage(
                subject: subject,
                highlightedSessionId: sessionId,
              ),
        ),
      );

      if (!mounted) {
        return;
      }

      appBloc.add(const ClassSessionNavigationConsumed());
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
              previous.pendingAcademicTaskId != current.pendingAcademicTaskId ||
              previous.pendingClassSessionId != current.pendingClassSessionId,
      listener: (context, state) {
        if (state.pendingAcademicTaskId != null) {
          _openPendingAcademicTask();
          return;
        }

        if (state.pendingClassSessionId != null &&
            state.pendingClassSubjectId != null) {
          _openPendingClassSession();
        }
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
            child: AcademicTasksView(
              onEditLauncherReady: (launcher) {
                _academicTaskEditLauncher = launcher;
              },
            ),
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
