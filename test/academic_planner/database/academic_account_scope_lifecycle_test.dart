import 'dart:async';

import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('close espera una operación activa', () async {
    final account = AcademicAccountScope.forUser('test-lifecycle-a');
    final finish = Completer<void>();
    var closed = false;

    final operation = account.run(() => finish.future);
    final closing = account.close().then((_) {
      closed = true;
    });

    await Future<void>.delayed(Duration.zero);

    expect(closed, isFalse);

    finish.complete();

    await operation;
    await closing;

    expect(closed, isTrue);
  });

  test('rechaza operaciones después de iniciar el cierre', () async {
    final account = AcademicAccountScope.forUser('test-lifecycle-b');

    await account.close();

    await expectLater(account.run(() async => 42), throwsStateError);
  });

  test('libera una operación aunque falle', () async {
    final account = AcademicAccountScope.forUser('test-lifecycle-c');

    await expectLater(
      account.run<void>(() async {
        throw StateError('Fallo de prueba');
      }),
      throwsStateError,
    );

    await account.close();
  });
}
