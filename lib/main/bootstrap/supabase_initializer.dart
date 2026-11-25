import 'package:flutter/foundation.dart';
import 'package:conecta_itt/env/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yx_scope/yx_scope.dart';

class SupabaseInitializer implements AsyncLifecycle {
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

    await Supabase.initialize(
      url: localRequested ? localUrl : Env.supabaseUrl,
      publishableKey: localRequested ? localAnonKey : Env.supabaseAnonKey,
    );
  }

  @override
  Future<void> dispose() async {
    // Scope rollback also disposes initializers after a startup failure.
    // Keep the persisted session available for the next startup attempt.
    await Supabase.instance.dispose();
  }
}
