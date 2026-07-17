import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rtu_mirea_app/announcements/models/models.dart';
import 'package:rtu_mirea_app/announcements/repositories/repositories.dart';
import 'package:rtu_mirea_app/institutional_profile/models/models.dart';

part 'announcement_event.dart';
part 'announcement_state.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  AnnouncementBloc({
    required AnnouncementRepository repository,
    required AppUserProfile profile,
  }) : _repository = repository,
       _profile = profile,
       super(const AnnouncementState()) {
    on<AnnouncementsStarted>(_onStarted);
    on<AnnouncementsChanged>(_onChanged);
    on<AnnouncementsFailed>(_onFailed);
  }

  final AnnouncementRepository _repository;
  final AppUserProfile _profile;

  StreamSubscription<List<Announcement>>? _subscription;

  Future<void> _onStarted(
    AnnouncementsStarted event,
    Emitter<AnnouncementState> emit,
  ) async {
    if (state.announcements.isEmpty) {
      emit(state.copyWith(status: AnnouncementsStatus.loading));
    }

    await _subscription?.cancel();

    _subscription = _repository
        .watchAnnouncementsForProfile(profile: _profile)
        .listen(
          (announcements) {
            add(AnnouncementsChanged(announcements));
          },
          onError: (Object error, StackTrace stackTrace) {
            add(AnnouncementsFailed(error, stackTrace));
          },
        );
  }

  Future<void> _onChanged(
    AnnouncementsChanged event,
    Emitter<AnnouncementState> emit,
  ) async {
    try {
      final receiptsByAnnouncementId = await _repository
          .fetchReceiptsForAnnouncements(
            announcementIds: event.announcements.map(
              (announcement) => announcement.id,
            ),
            userUid: _profile.uid,
          );

      emit(
        state.copyWith(
          status: AnnouncementsStatus.populated,
          announcements: event.announcements,
          receiptsByAnnouncementId: receiptsByAnnouncementId,
        ),
      );
    } catch (error, stackTrace) {
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

    addError(event.error, event.stackTrace);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
