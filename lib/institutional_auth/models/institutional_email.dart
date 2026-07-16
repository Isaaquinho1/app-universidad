import 'institutional_email_type.dart';

/// Value object that validates and classifies institutional email addresses.
class InstitutionalEmail {
  InstitutionalEmail._({
    required this.value,
    required this.type,
    this.controlNumber,
  });

  static final RegExp _studentPattern = RegExp(
    r'^l(\d{9})@tlalpan\.tecnm\.mx$',
    caseSensitive: false,
  );

  static final RegExp _campusStaffPattern = RegExp(
    r'^[a-z]+(?:[._-][a-z]+)+@tlalpan\.tecnm\.mx$',
    caseSensitive: false,
  );

  static final RegExp _tecnmStaffPattern = RegExp(
    r'^[a-z0-9]+(?:[._-][a-z0-9]+)*@tecnm\.mx$',
    caseSensitive: false,
  );

  /// Normalized lowercase email.
  final String value;

  /// Institutional category inferred from [value].
  final InstitutionalEmailType type;

  /// Student control number extracted from the email, when available.
  final String? controlNumber;

  bool get isValid => type.isValid;

  bool get isStudent => type.isStudent;

  bool get isStaff => type.isStaff;

  /// Parses and classifies [email].
  factory InstitutionalEmail.parse(String email) {
    final normalized = email.trim().toLowerCase();

    final studentMatch = _studentPattern.firstMatch(normalized);
    if (studentMatch != null) {
      return InstitutionalEmail._(
        value: normalized,
        type: InstitutionalEmailType.student,
        controlNumber: studentMatch.group(1),
      );
    }

    if (_campusStaffPattern.hasMatch(normalized)) {
      return InstitutionalEmail._(
        value: normalized,
        type: InstitutionalEmailType.campusStaff,
      );
    }

    if (_tecnmStaffPattern.hasMatch(normalized)) {
      return InstitutionalEmail._(
        value: normalized,
        type: InstitutionalEmailType.tecnmStaff,
      );
    }

    return InstitutionalEmail._(
      value: normalized,
      type: InstitutionalEmailType.invalid,
    );
  }
}
