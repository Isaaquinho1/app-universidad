import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/announcements/models/models.dart';
import 'package:conecta_itt/announcements/repositories/repositories.dart';
import 'package:conecta_itt/institutional_profile/models/models.dart';

part 'announcement_event.dart';
part 'announcement_state.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  AnnouncementBloc({
    required AnnouncementRepository repository,
    required PublicationAssetRepository assetRepository,
    required AppUserProfile profile,
  }) : _repository = repository,
       _assetRepository = assetRepository,
       _profile = profile,
       super(const AnnouncementState()) {
    on<AnnouncementsStarted>(_onStarted, transformer: sequential());
    on<AnnouncementsChanged>(_onChanged);
    on<AnnouncementsFailed>(_onFailed);
  }

  final AnnouncementRepository _repository;
  final PublicationAssetRepository _assetRepository;
  final AppUserProfile _profile;

  StreamSubscription<List<Announcement>>? _subscription;
  Completer<void>? _refreshCompletion;
  bool _closing = false;

  /// Waits for a fresh feed, including its receipts and assets, even when the
  /// resulting Equatable state is identical to the currently displayed state.
  Future<void> refresh() {
    if (_closing || isClosed) {
      return Future<void>.error(StateError('Announcement feed is closed'));
    }
    final pending = _refreshCompletion;
    if (pending != null) return pending.future;

    final completion = Completer<void>();
    _refreshCompletion = completion;
    add(AnnouncementsStarted(refreshCompletion: completion));
    return completion.future;
  }

  void _finishRefresh(
    Completer<void>? completion, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (completion == null || completion.isCompleted) return;
    if (identical(_refreshCompletion, completion)) _refreshCompletion = null;
    if (error == null) {
      completion.complete();
    } else {
      completion.completeError(error, stackTrace);
    }
  }

  Future<void> _onStarted(
    AnnouncementsStarted event,
    Emitter<AnnouncementState> emit,
  ) async {
    if (state.announcements.isEmpty &&
        state.status != AnnouncementsStatus.populated) {
      emit(state.copyWith(status: AnnouncementsStatus.loading));
    }

    try {
      await _subscription?.cancel();
      if (_closing || isClosed) return;

      var receivedValue = false;
      _subscription = _repository
          .watchAnnouncementsForProfile(profile: _profile)
          .listen(
            (announcements) {
              if (_closing || isClosed) return;
              receivedValue = true;
              add(
                AnnouncementsChanged(
                  announcements,
                  refreshCompletion: event.refreshCompletion,
                ),
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              if (_closing || isClosed) return;
              add(
                AnnouncementsFailed(
                  error,
                  stackTrace,
                  refreshCompletion: event.refreshCompletion,
                ),
              );
            },
            onDone: () {
              if (!receivedValue &&
                  event.refreshCompletion?.isCompleted == false &&
                  !_closing &&
                  !isClosed) {
                add(
                  AnnouncementsFailed(
                    StateError('Announcement feed closed without a response'),
                    StackTrace.current,
                    refreshCompletion: event.refreshCompletion,
                  ),
                );
              }
            },
          );
    } catch (error, stackTrace) {
      if (_closing || isClosed) return;
      add(
        AnnouncementsFailed(
          error,
          stackTrace,
          refreshCompletion: event.refreshCompletion,
        ),
      );
    }
  }

  Future<void> _onChanged(
    AnnouncementsChanged event,
    Emitter<AnnouncementState> emit,
  ) async {
    Object? refreshError;
    StackTrace? refreshStackTrace;
    try {
      final announcementIds = event.announcements
          .map((announcement) => announcement.id)
          .toList(growable: false);

      final receiptsFuture = _repository.fetchReceiptsForAnnouncements(
        announcementIds: announcementIds,
        userUid: _profile.uid,
      );

      final assetsFuture = _assetRepository.fetchAssetsForPublications(
        publicationIds: announcementIds,
      ).onError((Object error, StackTrace stackTrace) {
        refreshError = error;
        refreshStackTrace = stackTrace;
        addError(error, stackTrace);
        return <String, List<PublicationAsset>>{};
      });

      // Attach handlers to both requests immediately and wait for both, even
      // if receipts fail or assets fail before receipts have completed.
      final results = await Future.wait<Object>([receiptsFuture, assetsFuture]);
      final receiptsByAnnouncementId =
          results[0] as Map<String, AnnouncementReceipt>;
      final assetsByAnnouncementId =
          results[1] as Map<String, List<PublicationAsset>>;

      emit(
        state.copyWith(
          status: AnnouncementsStatus.populated,
          announcements: event.announcements,
          receiptsByAnnouncementId: receiptsByAnnouncementId,
          assetsByAnnouncementId: assetsByAnnouncementId,
        ),
      );
    } catch (error, stackTrace) {
      refreshError = error;
      refreshStackTrace = stackTrace;
      emit(
        state.copyWith(
          status:
              event.announcements.isEmpty
                  ? AnnouncementsStatus.failure
                  : AnnouncementsStatus.populated,
          announcements: event.announcements,
        ),
      );

      addError(error, stackTrace);
    } finally {
      _finishRefresh(
        event.refreshCompletion,
        error: refreshError,
        stackTrace: refreshStackTrace,
      );
    }
  }

  void _onFailed(AnnouncementsFailed event, Emitter<AnnouncementState> emit) {
    emit(
      state.copyWith(
        status:
            state.announcements.isEmpty
                ? AnnouncementsStatus.failure
                : AnnouncementsStatus.populated,
      ),
    );

    _finishRefresh(
      event.refreshCompletion,
      error: event.error,
      stackTrace: event.stackTrace,
    );
    addError(event.error, event.stackTrace);
  }

  @override
  Future<void> close() async {
    _closing = true;
    _finishRefresh(
      _refreshCompletion,
      error: StateError('Announcement feed is closed'),
    );
    await _subscription?.cancel();
    return super.close();
  }
}
