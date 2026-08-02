/// One opaque, short-lived token used by the dynamic student ID QR.
class StudentIdQrToken {
  const StudentIdQrToken({
    required this.id,
    required this.value,
    required this.issuedAt,
    required this.expiresAt,
    required this.expiresInSeconds,
  });

  factory StudentIdQrToken.fromSupabase(Map<String, dynamic> data) {
    final id = data['token_id'] as String?;
    final value = data['token'] as String?;
    final issuedAt = DateTime.tryParse(data['issued_at']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(data['expires_at']?.toString() ?? '');
    final expiresInSeconds = (data['expires_in_seconds'] as num?)?.toInt();

    if (id == null ||
        id.trim().isEmpty ||
        value == null ||
        value.trim().isEmpty ||
        issuedAt == null ||
        expiresAt == null ||
        expiresInSeconds == null ||
        expiresInSeconds <= 0) {
      throw const FormatException(
        'El servidor devolvió un token QR incompleto.',
      );
    }

    return StudentIdQrToken(
      id: id,
      value: value,
      issuedAt: issuedAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      expiresInSeconds: expiresInSeconds,
    );
  }

  final String id;
  final String value;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int expiresInSeconds;

  Duration remainingAt(DateTime moment) {
    final remaining = expiresAt.difference(moment.toUtc());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  bool isExpiredAt(DateTime moment) {
    return !expiresAt.isAfter(moment.toUtc());
  }
}
