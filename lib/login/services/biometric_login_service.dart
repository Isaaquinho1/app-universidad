import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricLoginType { none, face, fingerprint, generic }

class BiometricLoginCredentials {
  const BiometricLoginCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class BiometricLoginService {
  BiometricLoginService({
    LocalAuthentication? localAuthentication,
    FlutterSecureStorage? secureStorage,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _enabledKey = 'biometric_login_enabled';
  static const _emailKey = 'biometric_login_email';
  static const _passwordKey = 'biometric_login_password';

  final LocalAuthentication _localAuthentication;
  final FlutterSecureStorage _secureStorage;

  Future<BiometricLoginType> getAvailableType() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return BiometricLoginType.none;
    }

    try {
      final supported = await _localAuthentication.isDeviceSupported();

      if (!supported) {
        return BiometricLoginType.none;
      }

      final biometrics = await _localAuthentication.getAvailableBiometrics();

      if (biometrics.contains(BiometricType.face)) {
        return BiometricLoginType.face;
      }

      if (biometrics.contains(BiometricType.fingerprint)) {
        return BiometricLoginType.fingerprint;
      }

      if (biometrics.isNotEmpty) {
        return BiometricLoginType.generic;
      }

      return BiometricLoginType.none;
    } catch (_) {
      return BiometricLoginType.none;
    }
  }

  Future<bool> hasSavedCredentials() async {
    final enabled = await _secureStorage.read(key: _enabledKey);
    final email = await _secureStorage.read(key: _emailKey);
    final password = await _secureStorage.read(key: _passwordKey);

    return enabled == 'true' &&
        email != null &&
        email.trim().isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<bool> authenticate() async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason:
            'Usa tus datos biométricos para iniciar sesión en Conecta ITT.',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _secureStorage.write(
      key: _emailKey,
      value: email.trim().toLowerCase(),
    );
    await _secureStorage.write(key: _passwordKey, value: password);
    await _secureStorage.write(key: _enabledKey, value: 'true');
  }

  Future<BiometricLoginCredentials?> readCredentials() async {
    final email = await _secureStorage.read(key: _emailKey);
    final password = await _secureStorage.read(key: _passwordKey);

    if (email == null ||
        email.trim().isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }

    return BiometricLoginCredentials(email: email, password: password);
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _enabledKey);
    await _secureStorage.delete(key: _emailKey);
    await _secureStorage.delete(key: _passwordKey);
  }
}
