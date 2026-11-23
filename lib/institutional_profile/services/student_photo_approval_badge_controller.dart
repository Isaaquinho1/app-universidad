import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:conecta_itt/institutional_profile/repositories/student_profile_photo_repository.dart';

/// Tracks an unseen approved credential photograph for one student.
///
/// Independent from the administrative photo-review badge.
class StudentPhotoApprovalBadgeController {
  StudentPhotoApprovalBadgeController._();

  static final instance = StudentPhotoApprovalBadgeController._();

  // Do not enable before the corresponding Supabase RPCs are deployed.
  static const bool enabled = false;

  final ValueNotifier<bool> hasUnseenApproval = ValueNotifier<bool>(false);

  StudentProfilePhotoRepository? _repository;
  String? _userId;
  Timer? _timer;

  int _generation = 0;
  int _revision = 0;
  bool _refreshing = false;

  void bind({
    required String userId,
    required StudentProfilePhotoRepository repository,
  }) {
    if (!enabled) {
      unbind();
      return;
    }

    if (_userId == userId && identical(_repository, repository)) {
      return;
    }

    unbind();

    _userId = userId;
    _repository = repository;

    unawaited(refresh());

    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(refresh()),
    );
  }

  void unbind() {
    _generation++;
    _revision++;

    _timer?.cancel();
    _timer = null;

    _repository = null;
    _userId = null;
    _refreshing = false;

    hasUnseenApproval.value = false;
  }

  Future<void> refresh() async {
    final repository = _repository;

    if (!enabled || repository == null || _userId == null || _refreshing) {
      return;
    }

    final generation = _generation;
    final revision = ++_revision;

    _refreshing = true;

    try {
      final unseen = await repository.hasUnseenApprovedPhoto();

      if (generation == _generation &&
          revision == _revision &&
          _userId != null) {
        hasUnseenApproval.value = unseen;
      }
    } catch (error) {
      if (generation == _generation) {
        // Preserve the current indicator on transient network errors.
        debugPrint('Student photo approval badge error: $error');
      }
    } finally {
      if (generation == _generation) {
        _refreshing = false;
      }
    }
  }
}
