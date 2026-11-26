import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent context for a password recovery operation.
///
/// Does not contain passwords, recovery tokens or access tokens.
class PasswordRecoveryContext {
  const PasswordRecoveryContext.pending() : userId = null, sessionId = null;

  PasswordRecoveryContext.bound({
    required String userId,
    required String sessionId,
  }) : userId = _requireIdentifier(userId),
       sessionId = _requireIdentifier(sessionId);

  final String? userId;
  final String? sessionId;

  bool get isPending => userId == null && sessionId == null;

  static String _requireIdentifier(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('Recovery identifier cannot be empty.');
    }

    return value;
  }

  bool matchesSession({required String userId, required String sessionId}) {
    return !isPending && this.userId == userId && this.sessionId == sessionId;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'status': isPending ? 'pending' : 'bound',
    'userId': userId,
    'sessionId': sessionId,
  };

  factory PasswordRecoveryContext.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException(
        'Unsupported password recovery context version.',
      );
    }

    if (json['status'] == 'pending' &&
        json['userId'] == null &&
        json['sessionId'] == null) {
      return const PasswordRecoveryContext.pending();
    }

    if (json['status'] == 'bound' &&
        json['userId'] is String &&
        json['sessionId'] is String) {
      return PasswordRecoveryContext.bound(
        userId: json['userId'] as String,
        sessionId: json['sessionId'] as String,
      );
    }

    throw const FormatException('Invalid password recovery context.');
  }
}

/// Stores recovery context independently of biometric credentials.
///
/// Storage and decoding failures must be handled by the caller.
/// They must never be interpreted as a normal authenticated session.
class PasswordRecoveryStorage {
  PasswordRecoveryStorage({FlutterSecureStorage? secureStorage}) {
    final storage = secureStorage ?? const FlutterSecureStorage();

    _read = () => storage.read(key: storageKey);
    _write = (value) => storage.write(key: storageKey, value: value);
    _delete = () => storage.delete(key: storageKey);
  }

  /// Allows injecting storage operations for unit testing.
  PasswordRecoveryStorage.withOperations({
    required Future<String?> Function() read,
    required Future<void> Function(String) write,
    required Future<void> Function() delete,
  }) : _read = read,
       _write = write,
       _delete = delete;

  static const storageKey = 'conecta_itt.password_recovery.context.v1';

  late final Future<String?> Function() _read;
  late final Future<void> Function(String) _write;
  late final Future<void> Function() _delete;

  /// Returns null only when no recovery context exists.
  Future<PasswordRecoveryContext?> read() async {
    final value = await _read();

    if (value == null) {
      return null;
    }

    final decoded = jsonDecode(value);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid stored password recovery context.');
    }

    return PasswordRecoveryContext.fromJson(decoded);
  }

  /// Must be called before starting recovery verification.
  Future<void> markPending() {
    return save(const PasswordRecoveryContext.pending());
  }

  /// Stores the context associated with a verified session.
  Future<void> bindSession({
    required String userId,
    required String sessionId,
  }) {
    return save(
      PasswordRecoveryContext.bound(userId: userId, sessionId: sessionId),
    );
  }

  Future<void> save(PasswordRecoveryContext context) {
    return _write(jsonEncode(context.toJson()));
  }

  /// The caller must invalidate the recovery session before clearing.
  Future<void> clear() => _delete();
}
