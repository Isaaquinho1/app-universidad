import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:conecta_itt/app/app.dart';

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
    final announcementId = state.pendingAnnouncementId;

    if (!state.status.isLoggedIn ||
        state.institutionalProfile == null ||
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
              previous.institutionalProfile != current.institutionalProfile ||
              previous.status != current.status,
      listener: (_, state) {
        _scheduleNavigation(state);
      },
      child: widget.child,
    );
  }
}
