import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rtu_mirea_app/announcements/models/models.dart';
import 'package:rtu_mirea_app/announcements/repositories/repositories.dart';

part 'announcement_receipt_state.dart';

class AnnouncementReceiptCubit extends Cubit<AnnouncementReceiptState> {
  AnnouncementReceiptCubit({
    required AnnouncementRepository repository,
    required String announcementId,
    required String userUid,
    required int contentVersion,
  }) : _repository = repository,
       _announcementId = announcementId,
       _userUid = userUid,
       _contentVersion = contentVersion,
       super(const AnnouncementReceiptState());

  final AnnouncementRepository _repository;
  final String _announcementId;
  final String _userUid;
  final int _contentVersion;

  StreamSubscription<AnnouncementReceipt?>? _receiptSubscription;
  Timer? _readTimer;

  Future<void> started() async {
    emit(
      state.copyWith(
        status: AnnouncementReceiptOperationStatus.loading,
        clearError: true,
      ),
    );

    await _receiptSubscription?.cancel();

    _receiptSubscription = _repository
        .watchReceipt(announcementId: _announcementId, userUid: _userUid)
        .listen(
          (receipt) {
            emit(
              state.copyWith(
                status: AnnouncementReceiptOperationStatus.ready,
                receipt: receipt,
                contentVersion: _contentVersion,
                clearError: true,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            emit(
              state.copyWith(
                status: AnnouncementReceiptOperationStatus.failure,
                error: error,
              ),
            );

            addError(error, stackTrace);
          },
        );

    try {
      await _advanceTo(AnnouncementReceiptStatus.seen);
      await _refreshReceipt();

      _readTimer?.cancel();
      _readTimer = Timer(const Duration(seconds: 5), () {
        unawaited(markRead());
      });
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: AnnouncementReceiptOperationStatus.failure,
          error: error,
        ),
      );

      addError(error, stackTrace);
    }
  }

  Future<void> markRead() async {
    if (state.isRead) {
      return;
    }

    try {
      await _advanceTo(AnnouncementReceiptStatus.read);
      await _refreshReceipt();
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: AnnouncementReceiptOperationStatus.failure,
          error: error,
        ),
      );

      addError(error, stackTrace);
    }
  }

  Future<void> confirmReading() async {
    if (state.isConfirmed) {
      return;
    }

    emit(
      state.copyWith(
        status: AnnouncementReceiptOperationStatus.confirming,
        clearError: true,
      ),
    );

    try {
      await _advanceTo(AnnouncementReceiptStatus.confirmed);
      await _refreshReceipt();

      emit(
        state.copyWith(
          status: AnnouncementReceiptOperationStatus.ready,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      emit(
        state.copyWith(
          status: AnnouncementReceiptOperationStatus.failure,
          error: error,
        ),
      );

      addError(error, stackTrace);
    }
  }

  Future<void> _advanceTo(AnnouncementReceiptStatus status) {
    return _repository.updateReceiptStatus(
      announcementId: _announcementId,
      userUid: _userUid,
      status: status,
    );
  }

  Future<void> _refreshReceipt() async {
    final receipt = await _repository.fetchReceipt(
      announcementId: _announcementId,
      userUid: _userUid,
    );

    emit(
      state.copyWith(
        status: AnnouncementReceiptOperationStatus.ready,
        receipt: receipt,
        contentVersion: _contentVersion,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() async {
    _readTimer?.cancel();
    await _receiptSubscription?.cancel();
    return super.close();
  }
}
