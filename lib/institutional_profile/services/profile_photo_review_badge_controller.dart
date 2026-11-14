import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:conecta_itt/institutional_profile/repositories/admin_profile_photo_repository.dart';

/// Shared notification count for administrative photograph reviews.
///
/// This is a notification indicator, not the total pending review count.
class ProfilePhotoReviewBadgeController {
  ProfilePhotoReviewBadgeController._();

  static final instance = ProfilePhotoReviewBadgeController._();

  final ValueNotifier<int> unseenCount = ValueNotifier<int>(0);

  AdminProfilePhotoRepository? _repository;
  String? _userId;
  Timer? _pollingTimer;

  int _generation = 0;
  int _requestRevision = 0;
  bool _refreshing = false;

  /// Starts monitoring for the specified administrator.
  ///
  /// Switching accounts clears the previous account's count.
  void bind({
    required String userId,
    required AdminProfilePhotoRepository repository,
  }) {
    if (_userId == userId && identical(_repository, repository)) {
      return;
    }

    unbind();

    _userId = userId;
    _repository = repository;

    unawaited(refresh());

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(refresh()),
    );
  }

  /// Clears the session-specific state.
  void unbind() {
    _generation++;
    _requestRevision++;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _repository = null;
    _userId = null;
    _refreshing = false;
    unseenCount.value = 0;
  }

  /// Reloads the badge from the authorized Supabase RPC.
  Future<void> refresh() async {
    final repository = _repository;

    if (repository == null || _userId == null || _refreshing) {
      return;
    }

    final generation = _generation;
    final revision = ++_requestRevision;

    _refreshing = true;

    try {
      final count = await repository.fetchUnseenPhotoReviewCount();

      if (generation == _generation &&
          revision == _requestRevision &&
          _userId != null) {
        unseenCount.value = count;
      }
    } catch (error) {
      if (generation == _generation && revision == _requestRevision) {
        // Do not display an old administrator's count after an error.
        unseenCount.value = 0;
        debugPrint('Photo review badge refresh failed: $error');
      }
    } finally {
      if (generation == _generation) {
        _refreshing = false;
      }
    }
  }

  /// Marks new photograph notifications as seen.
  ///
  /// Does not approve, reject, or change photographs.
  Future<void> markSeen() async {
    final repository = _repository;

    if (repository == null || _userId == null) {
      return;
    }

    final generation = _generation;

    await repository.markPhotoReviewsSeen();

    if (generation != _generation) {
      return;
    }

    // Invalidate a count request that began before the mark.
    _requestRevision++;
    unseenCount.value = 0;

    // Recheck in case a new submission arrived during the operation.
    await refresh();
  }
}
