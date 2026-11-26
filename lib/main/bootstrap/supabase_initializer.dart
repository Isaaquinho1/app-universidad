import 'dart:async';

import 'package:deep_link_client/deep_link_client.dart';
import 'package:flutter/foundation.dart';
import 'package:conecta_itt/login/services/authentication_link_policy.dart';
import 'package:conecta_itt/env/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yx_scope/yx_scope.dart';

class SupabaseInitializer implements AsyncLifecycle {
  SupabaseClient? _recoveryClient;

  StreamSubscription<Uri>? _authLinkSubscription;
  Future<void>? _activeAuthLinkOperation;
  Uri? _lastCompletedAuthLink;
  bool _acceptAuthLinks = false;

  /// Independent client for temporary password recovery sessions.
  SupabaseClient get recoveryClient {
    final client = _recoveryClient;

    if (client == null) {
      throw StateError('Recovery client is not initialized.');
    }

    return client;
  }

  @override
  Future<void> init() async {
    const localUrl = String.fromEnvironment('CONECTA_LOCAL_SUPABASE_URL');
    const localAnonKey = String.fromEnvironment(
      'CONECTA_LOCAL_SUPABASE_ANON_KEY',
    );

    final localRequested = localUrl.isNotEmpty || localAnonKey.isNotEmpty;

    if (localRequested) {
      if (!kDebugMode ||
          !const {
            'http://127.0.0.1:54321',
            'http://192.168.1.67:54321',
            'http://192.168.0.12:54321',
          }.contains(localUrl) ||
          localAnonKey.isEmpty) {
        throw StateError('Configuracion local de Supabase invalida');
      }
    }

    final url = localRequested ? localUrl : Env.supabaseUrl;
    final key = localRequested ? localAnonKey : Env.supabaseAnonKey;

    await Supabase.initialize(
      url: url,
      publishableKey: key,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );

    _recoveryClient = SupabaseClient(
      url,
      key,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );

    await _startAuthLinks();
  }

  /// Starts controlled authentication callback processing.
  Future<void> _startAuthLinks() async {
    final client = DeepLinkClient();

    _acceptAuthLinks = true;

    _authLinkSubscription = client.deepLinkStream.listen(
      _enqueueAuthLink,
      onError: (Object error, StackTrace stackTrace) {
        // Never expose authentication callback credentials.
      },
    );

    try {
      final initialLink = await client.getInitialLink();

      if (initialLink != null) {
        _enqueueAuthLink(initialLink);
      }
    } catch (_) {
      // Ordinary authentication remains available.
    }
  }

  void _enqueueAuthLink(Uri uri) {
    if (!_acceptAuthLinks ||
        _activeAuthLinkOperation != null ||
        _lastCompletedAuthLink == uri) {
      return;
    }

    final operation = _handleAuthLink(uri);

    _activeAuthLinkOperation = operation;

    unawaited(
      operation.whenComplete(() {
        if (identical(_activeAuthLinkOperation, operation)) {
          _activeAuthLinkOperation = null;
        }
      }),
    );
  }

  Future<void> _handleAuthLink(Uri uri) async {
    try {
      final kind = AuthenticationLinkPolicy.classify(uri);

      // Password recovery uses manually entered OTP codes.
      // Recovery links must not reach the main auth client.
      if (kind != AuthenticationLinkKind.emailConfirmation) {
        return;
      }

      final code = uri.queryParameters['code'];

      if (code == null ||
          code.isEmpty ||
          uri.hasFragment ||
          uri.queryParametersAll.length != 1) {
        return;
      }

      final auth = Supabase.instance.client.auth;

      if (!_acceptAuthLinks || auth.currentSession != null) {
        return;
      }

      await auth.exchangeCodeForSession(code);

      _lastCompletedAuthLink = uri;
    } catch (_) {
      // Invalid or expired callbacks must not crash the app.
      // Never log complete URLs, codes or tokens.
    }
  }

  @override
  Future<void> dispose() async {
    _acceptAuthLinks = false;

    await _authLinkSubscription?.cancel();
    _authLinkSubscription = null;

    await _activeAuthLinkOperation;
    _activeAuthLinkOperation = null;
    _lastCompletedAuthLink = null;

    // Scope rollback also disposes initializers after a startup failure.
    // Keep the persisted session available for the next startup attempt.
    final recoveryClient = _recoveryClient;
    _recoveryClient = null;

    try {
      await recoveryClient?.dispose();
    } finally {
      await Supabase.instance.dispose();
    }
  }
}
