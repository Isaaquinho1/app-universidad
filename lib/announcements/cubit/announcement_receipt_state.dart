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
    this.contentVersion = 1,
    this.error,
  });

  final AnnouncementReceiptOperationStatus status;
  final AnnouncementReceipt? receipt;
  final int contentVersion;
  final Object? error;

  bool get isOutdated =>
      receipt != null && receipt!.receiptVersion < contentVersion;

  bool get isSeen => !isOutdated && (receipt?.isSeen ?? false);

  bool get isRead => !isOutdated && (receipt?.isRead ?? false);

  bool get isConfirmed => !isOutdated && (receipt?.isConfirmed ?? false);

  AnnouncementReceiptState copyWith({
    AnnouncementReceiptOperationStatus? status,
    AnnouncementReceipt? receipt,
    int? contentVersion,
    Object? error,
    bool clearError = false,
  }) {
    return AnnouncementReceiptState(
      status: status ?? this.status,
      receipt: receipt ?? this.receipt,
      contentVersion: contentVersion ?? this.contentVersion,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, receipt, contentVersion, error];
}
