import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/view/academic_tasks_view.dart';
import 'package:conecta_itt/academic_planner/view/subject_sessions_page.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_subject_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_task_repository.dart';
import 'package:conecta_itt/academic_planner/view/daily_schedule_view.dart';
import 'package:conecta_itt/academic_planner/view/subjects_management_view.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_planner_section_switch.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/academic_planner/view/academic_task_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _titleStyle = TextStyle(
  fontSize: 26.5,
  height: 1.05,
  letterSpacing: -1.1,
  fontWeight: FontWeight.w800,
  color: Color(0xFF111827),
);

class AcademicPlannerPage extends StatefulWidget {
  const AcademicPlannerPage({required this.account, super.key});

  final AcademicAccountScope account;

  @override
  State<AcademicPlannerPage> createState() => _AcademicPlannerPageState();
}

class _AcademicPlannerPageState extends State<AcademicPlannerPage> {
  static const _tasksIndex = 1;
  static const _subjectsIndex = 2;

  late final AcademicSubjectRepository _subjectRepository =
      widget.account.subjects;

  late final AcademicTaskRepository _taskRepository = widget.account.tasks;

  int _selectedIndex = 0;
  bool _initialNavigationChecked = false;

  late final AppBloc _appBloc;
  late final int _openingAuthRevision;

  bool get _isCurrentAccount {
    if (!mounted) return false;

    final state = _appBloc.state;

    return state.status.isLoggedIn &&
        state.user.id.trim() == widget.account.userId &&
        _appBloc.authRevision == _openingAuthRevision;
  }

  @override
  void initState() {
    super.initState();
    _appBloc = context.read<AppBloc>();
    _openingAuthRevision = _appBloc.authRevision;
  }

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
      if (!mounted || !_isCurrentAccount) {
        return;
      }

      final appBloc = _appBloc;
      final taskId = appBloc.state.pendingAcademicTaskId;

      if (taskId == null || taskId.isEmpty) {
        return;
      }

      if (_selectedIndex != _tasksIndex) {
        setState(() {
          _selectedIndex = _tasksIndex;
        });
      }

      final task =
          await (() async {
            try {
              return await widget.account.run(
                () => _taskRepository.getById(taskId),
              );
            } on StateError {
              if (!mounted || !_isCurrentAccount) {
                return null;
              }
              rethrow;
            }
          })();

      if (!mounted || !_isCurrentAccount) {
        return;
      }

      if (!mounted || !_isCurrentAccount) {
        return;
      }

      if (task == null) {
        appBloc.add(
          AcademicTaskNavigationConsumed(
            taskId: taskId,
            authRevision: _openingAuthRevision,
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La tarea ya no está disponible.')),
        );
        return;
      }

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder:
              (_) => AcademicTaskDetailPage(
                account: widget.account,
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

      if (!mounted || !_isCurrentAccount) {
        return;
      }

      appBloc.add(
        AcademicTaskNavigationConsumed(
          taskId: taskId,
          authRevision: _openingAuthRevision,
        ),
      );
    });
  }

  void _openPendingClassSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_isCurrentAccount) {
        return;
      }

      final appBloc = _appBloc;
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

      final subject =
          await (() async {
            try {
              return await widget.account.run(
                () => _subjectRepository.getById(subjectId),
              );
            } on StateError {
              if (!mounted || !_isCurrentAccount) {
                return null;
              }
              rethrow;
            }
          })();

      if (!mounted || !_isCurrentAccount) {
        return;
      }

      if (!mounted || !_isCurrentAccount) {
        return;
      }

      if (subject == null) {
        appBloc.add(
          ClassSessionNavigationConsumed(
            sessionId: sessionId,
            subjectId: subjectId,
            authRevision: _openingAuthRevision,
          ),
        );

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
                account: widget.account,
                subject: subject,
                highlightedSessionId: sessionId,
              ),
        ),
      );

      if (!mounted || !_isCurrentAccount) {
        return;
      }

      appBloc.add(
        ClassSessionNavigationConsumed(
          sessionId: sessionId,
          subjectId: subjectId,
          authRevision: _openingAuthRevision,
        ),
      );
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Horario', style: _titleStyle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(54),
            child: AcademicPlannerSectionSwitch(
              selectedIndex: _selectedIndex,
              onSelected: _selectSection,
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              DailyScheduleView(account: widget.account),
              AcademicTasksView(
                account: widget.account,
                onEditLauncherReady: (launcher) {
                  _academicTaskEditLauncher = launcher;
                },
              ),
              SubjectsManagementView(account: widget.account),
            ],
          ),
        ),
      ),
    );
  }
}
