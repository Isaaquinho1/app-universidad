import 'dart:async';

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
    on<AnnouncementsStarted>(_onStarted);
    on<AnnouncementsChanged>(_onChanged);
    on<AnnouncementsFailed>(_onFailed);
  }

  final AnnouncementRepository _repository;
  final PublicationAssetRepository _assetRepository;
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
      final announcementIds = event.announcements
          .map((announcement) => announcement.id)
          .toList(growable: false);

      final receiptsFuture = _repository.fetchReceiptsForAnnouncements(
        announcementIds: announcementIds,
        userUid: _profile.uid,
      );

      final assetsFuture = _assetRepository.fetchAssetsForPublications(
        publicationIds: announcementIds,
      );

      final receiptsByAnnouncementId = await receiptsFuture;

      Map<String, List<PublicationAsset>> assetsByAnnouncementId;

      try {
        assetsByAnnouncementId = await assetsFuture;
      } catch (error, stackTrace) {
        assetsByAnnouncementId = const {};
        addError(error, stackTrace);
      }

      emit(
        state.copyWith(
          status: AnnouncementsStatus.populated,
          announcements: event.announcements,
          receiptsByAnnouncementId: receiptsByAnnouncementId,
          assetsByAnnouncementId: assetsByAnnouncementId,
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
