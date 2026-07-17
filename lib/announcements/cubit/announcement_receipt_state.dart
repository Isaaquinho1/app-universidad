part of 'announcement_receipt_cubit.dart';

enum AnnouncementReceiptOperationStatus {
  initial,
  loading,
  ready,
  confirming,
  failure,
}

class AnnouncementReceiptState extends Equatable {
  const AnnouncementReceiptState({
    this.status = AnnouncementReceiptOperationStatus.initial,
    this.receipt,
    this.error,
  });

  final AnnouncementReceiptOperationStatus status;
  final AnnouncementReceipt? receipt;
  final Object? error;

  bool get isSeen => receipt?.isSeen ?? false;

  bool get isRead => receipt?.isRead ?? false;

  bool get isConfirmed => receipt?.isConfirmed ?? false;

  AnnouncementReceiptState copyWith({
    AnnouncementReceiptOperationStatus? status,
    AnnouncementReceipt? receipt,
    Object? error,
    bool clearError = false,
  }) {
    return AnnouncementReceiptState(
      status: status ?? this.status,
      receipt: receipt ?? this.receipt,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, receipt, error];
}
