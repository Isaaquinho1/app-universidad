import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/di/app_scope.dart';
import 'package:conecta_itt/main/bootstrap/bootstrap.dart';
import 'package:yx_scope_flutter/yx_scope_flutter.dart';

void main() async {
  // Reuse an initialized scope when retrying instead of recreating services.
  final holder = AppScopeHolder();
  await bootstrap((_) async {
    if (holder.scope == null) await holder.create();

    final scope = holder.scope;
    if (scope == null) {
      throw Exception('Failed to initialize AppScope');
    }

    // Recovery cleanup must not prevent ordinary authentication.
    try {
      await scope.passwordRecoveryService.initializeRecoveryContext();
    } catch (_) {
      // The recovery service remains unavailable until cleanup succeeds.
      // Do not expose recovery credentials in startup diagnostics.
    }

    final user = await scope.userRepository.user.first;
    return ScopeProvider(holder: holder, child: App(user: user));
  });
}
