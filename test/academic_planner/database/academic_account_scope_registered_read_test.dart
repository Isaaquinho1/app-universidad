import 'dart:async';

import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('close espera una lectura registrada antes de finalizar', () async {
    final account = AcademicAccountScope.forUser('test-account-read');

    final started = Completer<void>();
    final release = Completer<void>();

    var finished = false;

    final read = account.run(() async {
      started.complete();
      await release.future;
    });

    await started.future;

    final closing = account.close().then((_) {
      finished = true;
    });

    // El cierre no debe completar mientras la operación siga activa.
    await Future<void>.delayed(Duration.zero);

    expect(finished, isFalse);

    release.complete();

    await read;
    await closing;

    expect(finished, isTrue);
  });
}
