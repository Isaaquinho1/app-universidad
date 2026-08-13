import 'package:conecta_itt/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class FirebaseInteractedMessageListener extends StatefulWidget {
  const FirebaseInteractedMessageListener({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<FirebaseInteractedMessageListener> createState() =>
      _FirebaseInteractedMessageListenerState();
}

class _FirebaseInteractedMessageListenerState
    extends State<FirebaseInteractedMessageListener> {
  String? _scheduledAnnouncementId;
  String? _scheduledAcademicTaskId;
  String? _scheduledClassSessionId;
  bool _initialStateChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialStateChecked) {
      return;
    }

    _initialStateChecked = true;
    _scheduleNavigation(context.read<AppBloc>().state);
  }

  void _scheduleNavigation(AppState state) {
    if (!state.status.isLoggedIn) {
      return;
    }

    final academicTaskId = state.pendingAcademicTaskId;

    if (academicTaskId != null &&
        academicTaskId.isNotEmpty &&
        academicTaskId != _scheduledAcademicTaskId) {
      _scheduledAcademicTaskId = academicTaskId;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        widget.router.go('/schedule');
        _scheduledAcademicTaskId = null;
      });

      return;
    }

    final classSessionId = state.pendingClassSessionId;

    if (classSessionId != null &&
        classSessionId.isNotEmpty &&
        classSessionId != _scheduledClassSessionId) {
      _scheduledClassSessionId = classSessionId;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        widget.router.go('/schedule');
        _scheduledClassSessionId = null;
      });

      return;
    }

    final announcementId = state.pendingAnnouncementId;

    if (state.institutionalProfile == null ||
        announcementId == null ||
        announcementId.isEmpty ||
        announcementId == _scheduledAnnouncementId) {
      return;
    }

    _scheduledAnnouncementId = announcementId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.router.go(
        '/feed/announcement/${Uri.encodeComponent(announcementId)}',
      );

      context.read<AppBloc>().add(const AnnouncementNavigationConsumed());

      _scheduledAnnouncementId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen:
          (previous, current) =>
              previous.pendingAnnouncementId != current.pendingAnnouncementId ||
              previous.pendingAcademicTaskId != current.pendingAcademicTaskId ||
              previous.pendingClassSessionId != current.pendingClassSessionId ||
              previous.institutionalProfile != current.institutionalProfile ||
              previous.status != current.status,
      listener: (_, state) {
        _scheduleNavigation(state);
      },
      child: widget.child,
    );
  }
}
