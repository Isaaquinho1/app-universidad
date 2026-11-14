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
  String? _scheduledPhotoReviewKey;
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

    // Photograph notifications are bound to the active account.
    final photoDecision = state.pendingPhotoReviewDecision;
    final photoOwner = state.pendingPhotoReviewUserId;
    final photoRevision = state.pendingPhotoReviewAuthRevision;

    if (photoDecision != null &&
        photoOwner != null &&
        photoRevision != null &&
        state.status == AppStatus.authenticated &&
        state.institutionalProfile != null &&
        state.user.id == photoOwner &&
        (photoDecision == 'approved' || photoDecision == 'rejected')) {
      final appBloc = context.read<AppBloc>();

      if (appBloc.authRevision == photoRevision) {
        final navigationKey = '$photoOwner:$photoRevision:$photoDecision';

        if (_scheduledPhotoReviewKey != navigationKey) {
          _scheduledPhotoReviewKey = navigationKey;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            final currentBloc = context.read<AppBloc>();
            final current = currentBloc.state;

            if (current.status != AppStatus.authenticated ||
                current.institutionalProfile == null ||
                current.user.id != photoOwner ||
                currentBloc.authRevision != photoRevision ||
                current.pendingPhotoReviewUserId != photoOwner ||
                current.pendingPhotoReviewAuthRevision != photoRevision ||
                current.pendingPhotoReviewDecision != photoDecision) {
              _scheduledPhotoReviewKey = null;
              return;
            }

            widget.router.go('/profile/student-id');

            currentBloc.add(
              ProfilePhotoReviewNavigationConsumed(
                userId: photoOwner,
                authRevision: photoRevision,
              ),
            );

            _scheduledPhotoReviewKey = null;
          });
        }

        return;
      }
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
              previous.pendingPhotoReviewDecision !=
                  current.pendingPhotoReviewDecision ||
              previous.pendingPhotoReviewUserId !=
                  current.pendingPhotoReviewUserId ||
              previous.pendingPhotoReviewAuthRevision !=
                  current.pendingPhotoReviewAuthRevision ||
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
