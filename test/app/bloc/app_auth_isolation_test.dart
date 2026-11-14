import 'dart:async';

import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_pending_cleanup_service.dart';
import 'package:conecta_itt/app/bloc/app_bloc.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:user_repository/user_repository.dart';

class _MemoryStorage implements Storage {
  final _values = <String, dynamic>{};

  @override
  dynamic read(String key) => _values[key];

  @override
  Future<void> write(String key, dynamic value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUserRepository implements UserRepository {
  final changes = StreamController<User>.broadcast(sync: true);

  @override
  Stream<User> get user => changes.stream;

  @override
  Future<void> logOut() async {
    changes.add(User.anonymous);
  }

  Future<void> dispose() => changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestProfileRepository implements AppUserProfileRepository {
  final requests = <String, List<Completer<AppUserProfile>>>{};
  final updates = <String, StreamController<AppUserProfile?>>{};

  @override
  Future<AppUserProfile> ensureStudentProfile({
    required String uid,
    String? email,
    String? displayName,
  }) {
    final request = Completer<AppUserProfile>();
    requests.putIfAbsent(uid, () => []).add(request);
    return request.future;
  }

  @override
  Stream<AppUserProfile?> watchProfile(String uid) {
    return updates
        .putIfAbsent(
          uid,
          () => StreamController<AppUserProfile?>.broadcast(sync: true),
        )
        .stream;
  }

  Future<void> dispose() async {
    for (final controller in updates.values) {
      await controller.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAcademicCleanup extends AcademicReminderPendingCleanupService {
  final started = <String>[];
  Completer<void>? blockA;

  @override
  Future<int> cancelForeignAndLegacy({
    required String activeUserId,
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();

    started.add(activeUserId);

    if (activeUserId == 'A' && blockA != null) {
      await blockA!.future;
    }

    ensureCurrent?.call();
    return 0;
  }
}

class _TestMessaging implements FirebaseMessaging {
  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    throw StateError('FCM deshabilitado en esta prueba');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppUserProfile _profile(String uid, String name) {
  return AppUserProfile(
    uid: uid,
    displayName: name,
    role: AppUserRole.student,
    profileCompleted: true,
    active: true,
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('La condición esperada no se cumplió.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _TestUserRepository users;
  late _TestProfileRepository profiles;
  late AppBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MemoryStorage();
    users = _TestUserRepository();
    profiles = _TestProfileRepository();

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
    );
  });

  tearDown(() async {
    if (!bloc.isClosed) {
      await bloc.close();
    }
    await users.dispose();
    await profiles.dispose();
  });

  test('cerrar AppBloc invalida una operación académica pendiente', () async {
    const student = User(id: 'student-A');

    users.changes.add(student);
    await _waitUntil(
      () => bloc.academicReminderCoordinator.activeUserId == student.id,
    );

    final coordinator = bloc.academicReminderCoordinator;
    final revision = bloc.authRevision;

    final started = Completer<void>();
    final release = Completer<void>();

    final operation = coordinator.run(
      userId: student.id,
      revision: revision,
      operation: (lease) async {
        lease.ensureCurrent();
        started.complete();
        await release.future;
        lease.ensureCurrent();
      },
    );

    final assertion = expectLater(operation, throwsStateError);

    await started.future;
    await bloc.close();

    expect(coordinator.activeUserId, isNull);
    expect(coordinator.revision, greaterThan(revision));

    release.complete();
    await assertion;

    var executed = false;

    final staleResult = await coordinator.run(
      userId: student.id,
      revision: revision,
      operation: (_) async {
        executed = true;
      },
    );

    expect(staleResult, isFalse);
    expect(executed, isFalse);
  });

  test('AppOpened primero limpia después de validar el perfil', () async {
    await bloc.close();

    final cleanup = _RecordingAcademicCleanup();
    var initialized = false;

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      academicCleanupService: cleanup,
      initializeLocalNotifications: (_) async {
        initialized = true;
      },
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());
    await _waitUntil(() => initialized);

    expect(cleanup.started, isEmpty);

    users.changes.add(const User(id: 'A'));
    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

    expect(cleanup.started, isEmpty);

    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await _waitUntil(() => cleanup.started.length == 1);

    expect(cleanup.started, ['A']);
    expect(bloc.state.user.id, 'A');
    expect(bloc.state.status.isLoggedIn, isTrue);
  });

  test(
    'autenticación primero espera a que inicialicen notificaciones',
    () async {
      await bloc.close();

      final cleanup = _RecordingAcademicCleanup();
      final releaseInitialization = Completer<void>();
      var initializationStarted = false;

      bloc = AppBloc(
        firebaseMessaging: _TestMessaging(),
        userRepository: users,
        appUserProfileRepository: profiles,
        user: User.anonymous,
        academicCleanupService: cleanup,
        initializeLocalNotifications: (_) async {
          initializationStarted = true;
          await releaseInitialization.future;
        },
        configureRemoteMessaging: () async {},
      );

      users.changes.add(const User(id: 'B'));
      await _waitUntil(() => (profiles.requests['B']?.length ?? 0) == 1);

      profiles.requests['B']![0].complete(_profile('B', 'Estudiante B'));
      await _waitUntil(() => bloc.state.user.id == 'B');

      expect(cleanup.started, isEmpty);

      bloc.add(const AppOpened());
      await _waitUntil(() => initializationStarted);

      expect(cleanup.started, isEmpty);

      releaseInitialization.complete();

      await _waitUntil(() => cleanup.started.length == 1);
      expect(cleanup.started, ['B']);
    },
  );

  test('un perfil fallido no dispara limpieza académica', () async {
    await bloc.close();

    final cleanup = _RecordingAcademicCleanup();

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      academicCleanupService: cleanup,
      initializeLocalNotifications: (_) async {},
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    users.changes.add(const User(id: 'A'));
    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

    profiles.requests['A']![0].completeError(
      StateError('Fallo simulado de perfil'),
    );

    await _waitUntil(() => bloc.state.status == AppStatus.profileLoadFailed);

    expect(cleanup.started, isEmpty);
  });

  test('cambio A a B invalida la limpieza pendiente de A', () async {
    await bloc.close();

    final cleanup = _RecordingAcademicCleanup();
    cleanup.blockA = Completer<void>();

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      academicCleanupService: cleanup,
      initializeLocalNotifications: (_) async {},
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    users.changes.add(const User(id: 'A'));
    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);
    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await _waitUntil(() => cleanup.started.contains('A'));

    users.changes.add(const User(id: 'B'));
    await _waitUntil(() => (profiles.requests['B']?.length ?? 0) == 1);
    profiles.requests['B']![0].complete(_profile('B', 'Estudiante B'));

    await _waitUntil(() => bloc.state.user.id == 'B');

    // B queda encolada mientras la consulta simulada de A sigue activa.
    expect(cleanup.started, ['A']);

    cleanup.blockA!.complete();

    await _waitUntil(() => cleanup.started.contains('B'));

    expect(cleanup.started, ['A', 'B']);
    expect(bloc.state.user.id, 'B');
    expect(bloc.state.status.isLoggedIn, isTrue);
  });

  test('inicio en frío valida el perfil de una sesión persistente', () async {
    await bloc.close();

    final cleanup = _RecordingAcademicCleanup();
    var notificationsInitialized = false;

    // El repositorio de prueba no emite ningún evento inicial.
    // AppBloc debe procesar el usuario recibido en su constructor.
    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: const User(id: 'persisted-A'),
      academicCleanupService: cleanup,
      initializeLocalNotifications: (_) async {
        notificationsInitialized = true;
      },
      configureRemoteMessaging: () async {},
    );

    await _waitUntil(
      () => (profiles.requests['persisted-A']?.length ?? 0) == 1,
    );

    expect(cleanup.started, isEmpty);

    bloc.add(const AppOpened());
    await _waitUntil(() => notificationsInitialized);

    expect(cleanup.started, isEmpty);

    profiles.requests['persisted-A']![0].complete(
      _profile('persisted-A', 'Estudiante persistente'),
    );

    await _waitUntil(() => cleanup.started.contains('persisted-A'));

    expect(cleanup.started, ['persisted-A']);
    expect(bloc.state.user.id, 'persisted-A');
    expect(bloc.state.institutionalProfile?.uid, 'persisted-A');
    expect(bloc.state.status.isLoggedIn, isTrue);
  });

  test(
    'sesión persistente reemitida conserva una sola limpieza vigente',
    () async {
      await bloc.close();

      final cleanup = _RecordingAcademicCleanup();
      const persisted = User(id: 'persisted-A');

      bloc = AppBloc(
        firebaseMessaging: _TestMessaging(),
        userRepository: users,
        appUserProfileRepository: profiles,
        user: persisted,
        academicCleanupService: cleanup,
        initializeLocalNotifications: (_) async {},
        configureRemoteMessaging: () async {},
      );

      // Reemisión inmediata del mismo usuario por el repositorio.
      users.changes.add(persisted);
      bloc.add(const AppOpened());

      await _waitUntil(
        () => (profiles.requests[persisted.id]?.isNotEmpty ?? false),
      );

      // La revisión anterior no debe acabar autenticando por separado.
      expect(bloc.authRevision, 1);

      final requests = profiles.requests[persisted.id]!;
      expect(requests.length, 1);

      requests.single.complete(
        _profile(persisted.id, 'Estudiante persistente'),
      );

      await _waitUntil(() => cleanup.started.isNotEmpty);

      expect(cleanup.started, [persisted.id]);
      expect(bloc.state.user.id, persisted.id);
      expect(bloc.state.institutionalProfile?.uid, persisted.id);
      expect(bloc.state.status.isLoggedIn, isTrue);
    },
  );

  test(
    'reemisión del mismo usuario autenticado no reinicia la sesión',
    () async {
      await bloc.close();

      final cleanup = _RecordingAcademicCleanup();
      const student = User(id: 'student-A');

      bloc = AppBloc(
        firebaseMessaging: _TestMessaging(),
        userRepository: users,
        appUserProfileRepository: profiles,
        user: User.anonymous,
        academicCleanupService: cleanup,
        initializeLocalNotifications: (_) async {},
        configureRemoteMessaging: () async {},
      );

      bloc.add(const AppOpened());

      users.changes.add(student);
      await _waitUntil(() => (profiles.requests[student.id]?.length ?? 0) == 1);

      profiles.requests[student.id]![0].complete(
        _profile(student.id, 'Estudiante A'),
      );

      await _waitUntil(() => cleanup.started.length == 1);

      final originalRevision = bloc.authRevision;

      expect(bloc.state.user.id, student.id);
      expect(cleanup.started, [student.id]);

      // El proveedor emite nuevamente el mismo usuario autenticado.
      users.changes.add(student);

      // Permitir procesar los eventos asíncronos.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        bloc.authRevision,
        originalRevision,
        reason: 'Reemitir la misma sesión no debe invalidarla.',
      );

      expect(
        profiles.requests[student.id]?.length,
        1,
        reason: 'El perfil institucional no debe consultarse otra vez.',
      );

      expect(cleanup.started, [student.id]);
      expect(bloc.state.user.id, student.id);
    },
  );

  test('limpieza de B espera una operación académica pendiente de A', () async {
    await bloc.close();

    final cleanup = _RecordingAcademicCleanup();

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      academicCleanupService: cleanup,
      initializeLocalNotifications: (_) async {},
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    users.changes.add(const User(id: 'A'));
    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await _waitUntil(() => cleanup.started.contains('A'));

    final coordinator = bloc.academicReminderCoordinator;
    await coordinator.idle;

    final revisionA = bloc.authRevision;
    final startedA = Completer<void>();
    final releaseA = Completer<void>();

    final operationA = coordinator.run(
      userId: 'A',
      revision: revisionA,
      operation: (lease) async {
        lease.ensureCurrent();
        startedA.complete();

        // Representa una llamada al plugin todavía en curso.
        await releaseA.future;

        // Una vez liberada, A debe reconocer que fue invalidada.
        lease.ensureCurrent();
      },
    );

    final staleAssertion = expectLater(operationA, throwsStateError);

    await startedA.future;

    users.changes.add(const User(id: 'B'));

    await _waitUntil(() => (profiles.requests['B']?.length ?? 0) == 1);

    profiles.requests['B']![0].complete(_profile('B', 'Estudiante B'));

    await _waitUntil(() => bloc.state.user.id == 'B');

    expect(
      cleanup.started,
      ['A'],
      reason:
          'La limpieza de B no puede adelantarse '
          'a una operación pendiente de A.',
    );

    releaseA.complete();

    await staleAssertion;

    await _waitUntil(() => cleanup.started.contains('B'));
    await coordinator.idle;

    expect(cleanup.started, ['A', 'B']);
    expect(bloc.state.user.id, 'B');
    expect(bloc.state.status.isLoggedIn, isTrue);

    expect(coordinator.isCurrent(userId: 'A', revision: revisionA), isFalse);
  });

  test('reconciliación activada espera perfil y notificaciones', () async {
    await bloc.close();

    final calls = <String>[];
    final initialize = Completer<void>();
    var initializationStarted = false;

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      enableAcademicStartupReconciliation: true,
      academicStartupReconciliationOverride: (uid, revision) async {
        calls.add('$uid:$revision');
        return true;
      },
      initializeLocalNotifications: (_) async {
        initializationStarted = true;
        await initialize.future;
      },
      configureRemoteMessaging: () async {},
    );

    users.changes.add(const User(id: 'A'));

    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await _waitUntil(() => bloc.state.user.id == 'A');

    expect(calls, isEmpty);

    bloc.add(const AppOpened());
    await _waitUntil(() => initializationStarted);

    expect(calls, isEmpty);

    initialize.complete();

    await _waitUntil(() => calls.isNotEmpty);

    expect(calls, ['A:${bloc.authRevision}']);
  });

  test(
    'reconciliación activada funciona si AppOpened ocurre primero',
    () async {
      await bloc.close();

      final calls = <String>[];
      var initialized = false;

      bloc = AppBloc(
        firebaseMessaging: _TestMessaging(),
        userRepository: users,
        appUserProfileRepository: profiles,
        user: User.anonymous,
        enableAcademicStartupReconciliation: true,
        academicStartupReconciliationOverride: (uid, revision) async {
          calls.add(uid);
          return true;
        },
        initializeLocalNotifications: (_) async {
          initialized = true;
        },
        configureRemoteMessaging: () async {},
      );

      bloc.add(const AppOpened());
      await _waitUntil(() => initialized);

      expect(calls, isEmpty);

      users.changes.add(const User(id: 'B'));

      await _waitUntil(() => (profiles.requests['B']?.length ?? 0) == 1);

      expect(calls, isEmpty);

      profiles.requests['B']![0].complete(_profile('B', 'Estudiante B'));

      await _waitUntil(() => calls.isNotEmpty);

      expect(calls, ['B']);
      expect(bloc.state.status.isLoggedIn, isTrue);
    },
  );

  test('fallo de reconciliación no bloquea la autenticación', () async {
    await bloc.close();

    var attempts = 0;

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      enableAcademicStartupReconciliation: true,
      academicStartupReconciliationOverride: (uid, revision) async {
        attempts++;
        throw StateError('Restauración simulada fallida');
      },
      initializeLocalNotifications: (_) async {},
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    users.changes.add(const User(id: 'A'));

    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await _waitUntil(() => attempts == 1);

    expect(bloc.state.user.id, 'A');
    expect(bloc.state.status.isLoggedIn, isTrue);
    expect(bloc.state.institutionalProfile?.uid, 'A');
  });

  test('solicitudes simultáneas comparten reconciliación académica', () async {
    await bloc.close();

    final started = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    var initializations = 0;

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      enableAcademicStartupReconciliation: true,
      academicStartupReconciliationOverride: (uid, revision) async {
        calls++;
        if (!started.isCompleted) started.complete();
        await release.future;
        return true;
      },
      initializeLocalNotifications: (_) async {
        initializations++;
      },
      configureRemoteMessaging: () async {},
    );

    users.changes.add(const User(id: 'A'));
    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));
    await _waitUntil(() => bloc.state.user.id == 'A');

    bloc.add(const AppOpened());
    await started.future;

    expect(calls, 1);

    // Una segunda solicitud llega antes de terminar la primera.
    bloc.add(const AppOpened());

    await _waitUntil(() => initializations == 2);
    expect(calls, 1);

    release.complete();

    await bloc.academicReminderCoordinator.idle;
    expect(calls, 1);
  });

  test('cambio A a B invalida reconciliación anterior', () async {
    await bloc.close();

    final startedA = Completer<void>();
    final releaseA = Completer<void>();
    final calls = <String>[];

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      enableAcademicStartupReconciliation: true,
      academicStartupReconciliationOverride: (uid, revision) async {
        calls.add(uid);

        if (uid == 'A') {
          startedA.complete();
          await releaseA.future;
        }

        return true;
      },
      initializeLocalNotifications: (_) async {},
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    users.changes.add(const User(id: 'A'));
    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);
    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await startedA.future;

    final revisionA = bloc.authRevision;

    users.changes.add(const User(id: 'B'));
    await _waitUntil(() => (profiles.requests['B']?.length ?? 0) == 1);
    profiles.requests['B']![0].complete(_profile('B', 'Estudiante B'));

    await _waitUntil(() => calls.contains('B'));

    expect(
      bloc.academicReminderCoordinator.isCurrent(
        userId: 'A',
        revision: revisionA,
      ),
      isFalse,
    );

    releaseA.complete();

    await _waitUntil(() => bloc.state.user.id == 'B');

    expect(calls, ['A', 'B']);
    expect(bloc.state.institutionalProfile?.uid, 'B');
    expect(bloc.state.status.isLoggedIn, isTrue);
  });

  test('cerrar AppBloc invalida reconciliación pendiente', () async {
    await bloc.close();

    final started = Completer<void>();
    final release = Completer<void>();
    var calls = 0;

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      enableAcademicStartupReconciliation: true,
      academicStartupReconciliationOverride: (uid, revision) async {
        calls++;
        started.complete();
        await release.future;
        return true;
      },
      initializeLocalNotifications: (_) async {},
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    users.changes.add(const User(id: 'A'));
    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);
    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await started.future;

    final revisionA = bloc.authRevision;

    await bloc.close();

    expect(bloc.isClosed, isTrue);
    expect(
      bloc.academicReminderCoordinator.isCurrent(
        userId: 'A',
        revision: revisionA,
      ),
      isFalse,
    );

    release.complete();

    // El callback simulado puede finalizar, pero su sesión ya no es válida.
    expect(calls, 1);
  });

  test(
    'reconciliación exitosa no se repite al recibir otro AppOpened',
    () async {
      await bloc.close();

      var calls = 0;
      var initializations = 0;

      bloc = AppBloc(
        firebaseMessaging: _TestMessaging(),
        userRepository: users,
        appUserProfileRepository: profiles,
        user: User.anonymous,
        enableAcademicStartupReconciliation: true,
        academicStartupReconciliationOverride: (uid, revision) async {
          calls++;
          return true;
        },
        initializeLocalNotifications: (_) async {
          initializations++;
        },
        configureRemoteMessaging: () async {},
      );

      bloc.add(const AppOpened());

      users.changes.add(const User(id: 'A'));

      await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

      profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

      await _waitUntil(() => calls == 1);

      // Permitir que se registre el resultado exitoso.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      bloc.add(const AppOpened());

      await _waitUntil(() => initializations == 2);

      expect(calls, 1);
      expect(bloc.state.user.id, 'A');
      expect(bloc.state.status.isLoggedIn, isTrue);
    },
  );

  test('reconciliación fallida puede reintentarse con AppOpened', () async {
    await bloc.close();

    var attempts = 0;
    var initializations = 0;

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      enableAcademicStartupReconciliation: true,
      academicStartupReconciliationOverride: (uid, revision) async {
        attempts++;

        if (attempts == 1) {
          throw StateError('Fallo académico simulado');
        }

        return true;
      },
      initializeLocalNotifications: (_) async {
        initializations++;
      },
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    users.changes.add(const User(id: 'A'));

    await _waitUntil(() => (profiles.requests['A']?.length ?? 0) == 1);

    profiles.requests['A']![0].complete(_profile('A', 'Estudiante A'));

    await _waitUntil(() => attempts == 1);

    // La primera solicitud debe finalizar antes del reintento.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(bloc.state.status.isLoggedIn, isTrue);

    bloc.add(const AppOpened());

    await _waitUntil(() => initializations == 2);
    await _waitUntil(() => attempts == 2);

    expect(attempts, 2);
    expect(bloc.state.user.id, 'A');
    expect(bloc.state.institutionalProfile?.uid, 'A');
  });

  test('consumir tarea A no elimina la tarea B pendiente', () async {
    const student = User(id: 'student-A');

    users.changes.add(student);
    await _waitUntil(() => (profiles.requests[student.id]?.length ?? 0) == 1);
    profiles.requests[student.id]![0].complete(
      _profile(student.id, 'Estudiante A'),
    );
    await _waitUntil(() => bloc.state.user.id == student.id);

    final revision = bloc.authRevision;

    bloc.add(
      AcademicTaskNotificationOpened(
        'task-A',
        userId: bloc.state.user.id,
        authRevision: bloc.authRevision,
      ),
    );
    await _waitUntil(() => bloc.state.pendingAcademicTaskId == 'task-A');

    bloc.add(
      AcademicTaskNotificationOpened(
        'task-B',
        userId: bloc.state.user.id,
        authRevision: bloc.authRevision,
      ),
    );
    await _waitUntil(() => bloc.state.pendingAcademicTaskId == 'task-B');

    bloc.add(
      AcademicTaskNavigationConsumed(taskId: 'task-A', authRevision: revision),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.pendingAcademicTaskId, 'task-B');

    bloc.add(
      AcademicTaskNavigationConsumed(taskId: 'task-B', authRevision: revision),
    );

    await _waitUntil(() => bloc.state.pendingAcademicTaskId == null);
  });

  test('consumir sesión antigua conserva la sesión nueva', () async {
    const student = User(id: 'student-A');

    users.changes.add(student);
    await _waitUntil(() => (profiles.requests[student.id]?.length ?? 0) == 1);
    profiles.requests[student.id]![0].complete(
      _profile(student.id, 'Estudiante A'),
    );
    await _waitUntil(() => bloc.state.user.id == student.id);

    final revision = bloc.authRevision;

    bloc.add(
      ClassSessionNotificationOpened(
        sessionId: 'session-A',
        subjectId: 'subject-A',
        userId: bloc.state.user.id,
        authRevision: bloc.authRevision,
      ),
    );
    await _waitUntil(() => bloc.state.pendingClassSessionId == 'session-A');

    bloc.add(
      ClassSessionNotificationOpened(
        sessionId: 'session-B',
        subjectId: 'subject-B',
        userId: bloc.state.user.id,
        authRevision: bloc.authRevision,
      ),
    );
    await _waitUntil(() => bloc.state.pendingClassSessionId == 'session-B');

    bloc.add(
      ClassSessionNavigationConsumed(
        sessionId: 'session-A',
        subjectId: 'subject-A',
        authRevision: revision,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.pendingClassSessionId, 'session-B');
    expect(bloc.state.pendingClassSubjectId, 'subject-B');

    bloc.add(
      ClassSessionNavigationConsumed(
        sessionId: 'session-B',
        subjectId: 'subject-B',
        authRevision: revision,
      ),
    );

    await _waitUntil(() => bloc.state.pendingClassSessionId == null);
    expect(bloc.state.pendingClassSubjectId, isNull);
  });

  test('rechaza consumo académico de una revisión anterior', () async {
    const a = User(id: 'student-A');
    const b = User(id: 'student-B');

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);
    profiles.requests[a.id]![0].complete(_profile(a.id, 'A inicial'));
    await _waitUntil(() => bloc.state.user.id == a.id);

    final oldRevision = bloc.authRevision;

    users.changes.add(b);
    await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 1);
    profiles.requests[b.id]![0].complete(_profile(b.id, 'B'));
    await _waitUntil(() => bloc.state.user.id == b.id);

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 2);
    profiles.requests[a.id]![1].complete(_profile(a.id, 'A vigente'));
    await _waitUntil(
      () => bloc.state.institutionalProfile?.displayName == 'A vigente',
    );

    bloc.add(
      AcademicTaskNotificationOpened(
        'task-A',
        userId: bloc.state.user.id,
        authRevision: bloc.authRevision,
      ),
    );
    await _waitUntil(() => bloc.state.pendingAcademicTaskId == 'task-A');

    bloc.add(
      AcademicTaskNavigationConsumed(
        taskId: 'task-A',
        authRevision: oldRevision,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.pendingAcademicTaskId, 'task-A');

    bloc.add(
      AcademicTaskNavigationConsumed(
        taskId: 'task-A',
        authRevision: bloc.authRevision,
      ),
    );

    await _waitUntil(() => bloc.state.pendingAcademicTaskId == null);
  });

  test('rechaza consumo de sesión con materia incorrecta', () async {
    const student = User(id: 'student-A');

    users.changes.add(student);
    await _waitUntil(() => (profiles.requests[student.id]?.length ?? 0) == 1);
    profiles.requests[student.id]![0].complete(
      _profile(student.id, 'Estudiante A'),
    );
    await _waitUntil(() => bloc.state.user.id == student.id);

    final revision = bloc.authRevision;

    bloc.add(
      ClassSessionNotificationOpened(
        sessionId: 'session-A',
        subjectId: 'subject-A',
        userId: bloc.state.user.id,
        authRevision: bloc.authRevision,
      ),
    );
    await _waitUntil(() => bloc.state.pendingClassSessionId == 'session-A');

    bloc.add(
      ClassSessionNavigationConsumed(
        sessionId: 'session-A',
        subjectId: 'subject-incorrect',
        authRevision: revision,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.pendingClassSessionId, 'session-A');
    expect(bloc.state.pendingClassSubjectId, 'subject-A');

    bloc.add(
      ClassSessionNavigationConsumed(
        sessionId: 'session-A',
        subjectId: 'subject-A',
        authRevision: revision,
      ),
    );

    await _waitUntil(() => bloc.state.pendingClassSessionId == null);
  });

  test('el coordinador invalida inmediatamente A -> B -> A', () {
    const a = User(id: 'student-A');
    const b = User(id: 'student-B');

    final coordinator = bloc.academicReminderCoordinator;
    final initialRevision = bloc.authRevision;

    expect(coordinator.activeUserId, isNull);
    expect(coordinator.revision, initialRevision);

    users.changes.add(a);
    final firstRevisionA = bloc.authRevision;

    expect(firstRevisionA, initialRevision + 1);
    expect(
      coordinator.isCurrent(userId: a.id, revision: firstRevisionA),
      isTrue,
    );

    users.changes.add(b);
    final revisionB = bloc.authRevision;

    expect(
      coordinator.isCurrent(userId: a.id, revision: firstRevisionA),
      isFalse,
    );
    expect(coordinator.isCurrent(userId: b.id, revision: revisionB), isTrue);

    users.changes.add(a);
    final currentRevisionA = bloc.authRevision;

    expect(currentRevisionA, firstRevisionA + 2);
    expect(
      coordinator.isCurrent(userId: a.id, revision: firstRevisionA),
      isFalse,
    );
    expect(
      coordinator.isCurrent(userId: a.id, revision: currentRevisionA),
      isTrue,
    );

    users.changes.add(User.anonymous);

    expect(coordinator.activeUserId, isNull);
    expect(
      coordinator.isCurrent(userId: a.id, revision: currentRevisionA),
      isFalse,
    );
  });

  test('notifica revisiones inmediatamente en A -> B -> A', () async {
    const a = User(id: 'student-A');
    const b = User(id: 'student-B');

    final revisions = <int>[];
    final subscription = bloc.authRevisionChanges.listen(revisions.add);

    try {
      final initialRevision = bloc.authRevision;

      users.changes.add(a);

      expect(bloc.authRevision, initialRevision + 1);
      expect(revisions, [initialRevision + 1]);

      users.changes.add(b);

      expect(bloc.authRevision, initialRevision + 2);
      expect(revisions, [initialRevision + 1, initialRevision + 2]);

      users.changes.add(a);

      expect(bloc.authRevision, initialRevision + 3);
      expect(revisions, [
        initialRevision + 1,
        initialRevision + 2,
        initialRevision + 3,
      ]);
    } finally {
      await subscription.cancel();
    }
  });

  test(
    'cambio de identidad revierte una transacción académica pendiente',
    () async {
      const a = User(id: 'student-A');
      const b = User(id: 'student-B');

      users.changes.add(a);
      final revisionA = bloc.authRevision;

      final account = AcademicAccountScope.forUser(
        'test-auth-rollback-\${DateTime.now().microsecondsSinceEpoch}',
      );

      final subscription = bloc.authRevisionChanges.listen((revision) {
        if (revision != revisionA) {
          account.invalidate();
        }
      });

      final inserted = Completer<void>();
      final resume = Completer<void>();

      try {
        final operation = account.runTransaction<void>((transaction) async {
          await transaction.insert('task_categories', {
            'id': 'auth-rollback-category',
            'name': 'Categoría de sesión anterior',
            'color_value': 7,
            'is_system': 0,
            'created_at': DateTime.now().toIso8601String(),
          });

          inserted.complete();
          await resume.future;
        });

        await inserted.future;

        users.changes.add(b);

        expect(bloc.authRevision, revisionA + 1);

        resume.complete();

        await expectLater(operation, throwsStateError);

        final connection = await account.database.database;
        final rows = await connection.query(
          'task_categories',
          where: 'id = ?',
          whereArgs: ['auth-rollback-category'],
        );

        expect(rows, isEmpty);
      } finally {
        if (!resume.isCompleted) {
          resume.complete();
        }
        await subscription.cancel();
        await account.close();
      }
    },
  );

  test(
    'A -> B -> A: las respuestas antiguas no sustituyen la última sesión',
    () async {
      const a = User(id: 'student-A');
      const b = User(id: 'student-B');

      users.changes.add(a);
      await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);

      users.changes.add(b);
      await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 1);

      users.changes.add(a);
      await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 2);

      profiles.requests[a.id]![0].complete(_profile(a.id, 'A antigua'));
      profiles.requests[b.id]![0].complete(_profile(b.id, 'B antigua'));

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.state.user.id, isNot(a.id));
      expect(bloc.state.institutionalProfile?.displayName, isNot('A antigua'));

      profiles.requests[a.id]![1].complete(_profile(a.id, 'A vigente'));

      await _waitUntil(
        () => bloc.state.institutionalProfile?.displayName == 'A vigente',
      );

      expect(bloc.state.user.id, a.id);
      expect(bloc.state.institutionalProfile?.displayName, 'A vigente');
    },
  );

  test('un evento de perfil de una sesión anterior es rechazado', () async {
    const a = User(id: 'student-A');
    const b = User(id: 'student-B');

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);
    profiles.requests[a.id]![0].complete(_profile(a.id, 'Primera sesión'));

    await _waitUntil(() => bloc.state.user.id == a.id);

    final previousRevision = bloc.authRevision;

    users.changes.add(b);
    await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 1);
    profiles.requests[b.id]![0].complete(_profile(b.id, 'Cuenta B'));

    await _waitUntil(() => bloc.state.user.id == b.id);

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 2);
    profiles.requests[a.id]![1].complete(_profile(a.id, 'Segunda sesión'));

    await _waitUntil(
      () => bloc.state.institutionalProfile?.displayName == 'Segunda sesión',
    );

    bloc.add(
      AppInstitutionalProfileChanged(
        _profile(a.id, 'Perfil obsoleto'),
        userId: a.id,
        revision: previousRevision,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.user.id, a.id);
    expect(bloc.state.institutionalProfile?.displayName, 'Segunda sesión');
  });

  test('cerrar sesión invalida una consulta de perfil pendiente', () async {
    const student = User(id: 'student-A');

    users.changes.add(student);

    await _waitUntil(() => (profiles.requests[student.id]?.length ?? 0) == 1);

    // El perfil todavía no ha respondido.
    users.changes.add(User.anonymous);

    await _waitUntil(() => bloc.state.status == AppStatus.unauthenticated);

    // La consulta antigua responde después del cierre de sesión.
    profiles.requests[student.id]![0].complete(
      _profile(student.id, 'Perfil que llegó tarde'),
    );

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(bloc.state.status, AppStatus.unauthenticated);
    expect(bloc.state.user, User.anonymous);
    expect(bloc.state.institutionalProfile, isNull);
  });

  test('oculta la cuenta anterior mientras carga el nuevo perfil', () async {
    const a = User(id: 'student-A', isNewUser: false);
    const b = User(id: 'student-B', isNewUser: false);

    users.changes.add(a);

    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);

    profiles.requests[a.id]![0].complete(_profile(a.id, 'Estudiante A'));

    await _waitUntil(() => bloc.state.user.id == a.id);

    expect(bloc.state.status, AppStatus.authenticated);

    // Cambiamos a B, pero dejamos su consulta sin resolver.
    users.changes.add(b);

    await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 1);

    await _waitUntil(() => bloc.state.status == AppStatus.switchingAccount);

    expect(bloc.state.user, User.anonymous);
    expect(bloc.state.institutionalProfile, isNull);

    // Cuando responde B, únicamente aparece su información.
    profiles.requests[b.id]![0].complete(_profile(b.id, 'Estudiante B'));

    await _waitUntil(() => bloc.state.user.id == b.id);

    expect(bloc.state.status, AppStatus.authenticated);
    expect(bloc.state.institutionalProfile?.displayName, 'Estudiante B');
  });

  test('rechaza recordatorios de otra cuenta y acepta los propios', () async {
    const a = User(id: 'student-A');
    const b = User(id: 'student-B');

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);
    profiles.requests[a.id]![0].complete(_profile(a.id, 'Estudiante A'));
    await _waitUntil(() => bloc.state.user.id == a.id);

    final revisionA = bloc.authRevision;

    users.changes.add(b);
    await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 1);
    profiles.requests[b.id]![0].complete(_profile(b.id, 'Estudiante B'));
    await _waitUntil(() => bloc.state.user.id == b.id);

    final revisionB = bloc.authRevision;

    // Ningún registro de A debe abrirse en la sesión B.
    bloc.add(
      AcademicTaskNotificationOpened(
        'registro-compartido',
        userId: a.id,
        authRevision: revisionA,
      ),
    );

    bloc.add(
      ClassSessionNotificationOpened(
        sessionId: 'sesion-compartida',
        subjectId: 'materia-compartida',
        userId: a.id,
        authRevision: revisionA,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.user.id, b.id);
    expect(bloc.state.pendingAcademicTaskId, isNull);
    expect(bloc.state.pendingClassSessionId, isNull);
    expect(bloc.state.pendingClassSubjectId, isNull);

    // Los mismos IDs sí pueden pertenecer legítimamente a B.
    bloc.add(
      AcademicTaskNotificationOpened(
        'registro-compartido',
        userId: b.id,
        authRevision: revisionB,
      ),
    );

    bloc.add(
      ClassSessionNotificationOpened(
        sessionId: 'sesion-compartida',
        subjectId: 'materia-compartida',
        userId: b.id,
        authRevision: revisionB,
      ),
    );

    await _waitUntil(
      () =>
          bloc.state.pendingAcademicTaskId == 'registro-compartido' &&
          bloc.state.pendingClassSessionId == 'sesion-compartida',
    );

    expect(bloc.state.pendingClassSubjectId, 'materia-compartida');
  });

  test('A -> B -> A rechaza eventos de una revision anterior', () async {
    const a = User(id: 'student-A');
    const b = User(id: 'student-B');

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);
    profiles.requests[a.id]![0].complete(_profile(a.id, 'Estudiante A'));
    await _waitUntil(() => bloc.state.user.id == a.id);

    final oldRevisionA = bloc.authRevision;

    users.changes.add(b);
    await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 1);
    profiles.requests[b.id]![0].complete(_profile(b.id, 'Estudiante B'));
    await _waitUntil(() => bloc.state.user.id == b.id);

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 2);
    profiles.requests[a.id]![1].complete(_profile(a.id, 'Estudiante A'));
    await _waitUntil(
      () => bloc.state.user.id == a.id && bloc.authRevision > oldRevisionA,
    );

    final currentRevisionA = bloc.authRevision;

    bloc.add(
      AcademicTaskNotificationOpened(
        'tarea-antigua',
        userId: a.id,
        authRevision: oldRevisionA,
      ),
    );

    bloc.add(
      ClassSessionNotificationOpened(
        sessionId: 'clase-antigua',
        subjectId: 'materia-antigua',
        userId: a.id,
        authRevision: oldRevisionA,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.pendingAcademicTaskId, isNull);
    expect(bloc.state.pendingClassSessionId, isNull);
    expect(bloc.state.pendingClassSubjectId, isNull);

    bloc.add(
      AcademicTaskNotificationOpened(
        'tarea-vigente',
        userId: a.id,
        authRevision: currentRevisionA,
      ),
    );

    bloc.add(
      ClassSessionNotificationOpened(
        sessionId: 'clase-vigente',
        subjectId: 'materia-vigente',
        userId: a.id,
        authRevision: currentRevisionA,
      ),
    );

    await _waitUntil(
      () =>
          bloc.state.pendingAcademicTaskId == 'tarea-vigente' &&
          bloc.state.pendingClassSessionId == 'clase-vigente',
    );

    expect(bloc.state.pendingClassSubjectId, 'materia-vigente');
  });

  test('el estado de transición nunca se guarda como sesión activa', () {
    const transitioning = AppState(status: AppStatus.switchingAccount);

    final json = bloc.toJson(transitioning);

    expect(json, {'isAmoled': false});
  });

  test('HydratedBloc no restaura identidades ni sesiones obsoletas', () async {
    final restoredWithoutSession = bloc.fromJson({
      'isAmoled': true,
      'status': AppStatus.authenticated.index,
    });

    expect(restoredWithoutSession?.status, AppStatus.unauthenticated);
    expect(restoredWithoutSession?.user, User.anonymous);
    expect(restoredWithoutSession?.isAmoled, isTrue);

    const a = User(id: 'student-A', isNewUser: false);

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);

    profiles.requests[a.id]![0].complete(_profile(a.id, 'Estudiante A'));
    await _waitUntil(() => bloc.state.user.id == a.id);

    final restoredWithSession = bloc.fromJson({
      'isAmoled': false,
      'status': AppStatus.unauthenticated.index,
    });

    expect(restoredWithSession?.status, AppStatus.authenticated);
    expect(restoredWithSession?.user.id, a.id);
    expect(restoredWithSession?.institutionalProfile?.uid, a.id);
  });

  test('un error de perfil permite reintentar sin mostrar A', () async {
    const a = User(id: 'student-A', isNewUser: false);
    const b = User(id: 'student-B', isNewUser: false);

    users.changes.add(a);
    await _waitUntil(() => (profiles.requests[a.id]?.length ?? 0) == 1);

    profiles.requests[a.id]![0].complete(_profile(a.id, 'Estudiante A'));
    await _waitUntil(() => bloc.state.user.id == a.id);

    users.changes.add(b);
    await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 1);

    profiles.requests[b.id]![0].completeError(
      StateError('Fallo simulado de perfil'),
    );

    await _waitUntil(() => bloc.state.status == AppStatus.profileLoadFailed);

    expect(bloc.state.user, User.anonymous);
    expect(bloc.state.institutionalProfile, isNull);

    expect(bloc.toJson(bloc.state), {'isAmoled': false});

    bloc.add(const AppProfileRetryRequested());

    await _waitUntil(() => (profiles.requests[b.id]?.length ?? 0) == 2);

    expect(bloc.state.status, AppStatus.switchingAccount);
    expect(bloc.state.institutionalProfile, isNull);

    profiles.requests[b.id]![1].complete(_profile(b.id, 'Estudiante B'));

    await _waitUntil(() => bloc.state.user.id == b.id);

    expect(bloc.state.status, AppStatus.authenticated);
    expect(bloc.state.institutionalProfile?.displayName, 'Estudiante B');
  });

  // ================================================================
  // CORRECCIÓN 13.6I
  // Navegación de fotografías vinculada a la sesión autenticada.
  // ================================================================

  Future<int> signInPhotoStudent(String uid) async {
    users.changes.add(User(id: uid, isNewUser: false));

    await _waitUntil(() => (profiles.requests[uid]?.length ?? 0) == 1);

    profiles.requests[uid]![0].complete(_profile(uid, 'Estudiante de prueba'));

    await _waitUntil(
      () =>
          bloc.state.user.id == uid &&
          bloc.state.status == AppStatus.authenticated &&
          bloc.state.institutionalProfile?.uid == uid,
    );

    return bloc.authRevision;
  }

  test('13.6I - fotografía aprobada para la cuenta activa', () async {
    const uid = 'photo-student-A';
    final revision = await signInPhotoStudent(uid);

    bloc.add(
      ProfilePhotoReviewNotificationOpened(
        decision: 'approved',
        userId: uid,
        authRevision: revision,
      ),
    );

    await _waitUntil(() => bloc.state.pendingPhotoReviewDecision == 'approved');

    expect(bloc.state.pendingPhotoReviewUserId, uid);
    expect(bloc.state.pendingPhotoReviewAuthRevision, revision);
  });

  test('13.6I - fotografía rechazada para la cuenta activa', () async {
    const uid = 'photo-student-A';
    final revision = await signInPhotoStudent(uid);

    bloc.add(
      ProfilePhotoReviewNotificationOpened(
        decision: 'rejected',
        userId: uid,
        authRevision: revision,
      ),
    );

    await _waitUntil(() => bloc.state.pendingPhotoReviewDecision == 'rejected');

    expect(bloc.state.pendingPhotoReviewUserId, uid);
  });

  test('13.6I - rechaza un destinatario diferente', () async {
    const uid = 'photo-student-A';
    final revision = await signInPhotoStudent(uid);

    bloc.add(
      ProfilePhotoReviewNotificationOpened(
        decision: 'approved',
        userId: 'photo-student-B',
        authRevision: revision,
      ),
    );

    // La comprobación negativa permite procesar el evento del BLoC.
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.pendingPhotoReviewDecision, isNull);
    expect(bloc.state.pendingPhotoReviewUserId, isNull);
  });

  test('13.6I - rechaza una revisión de sesión antigua', () async {
    const uid = 'photo-student-A';
    final revision = await signInPhotoStudent(uid);

    bloc.add(
      ProfilePhotoReviewNotificationOpened(
        decision: 'approved',
        userId: uid,
        authRevision: revision - 1,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.pendingPhotoReviewDecision, isNull);
  });

  test('13.6I - consume una navegación válida', () async {
    const uid = 'photo-student-A';
    final revision = await signInPhotoStudent(uid);

    bloc.add(
      ProfilePhotoReviewNotificationOpened(
        decision: 'approved',
        userId: uid,
        authRevision: revision,
      ),
    );

    await _waitUntil(() => bloc.state.pendingPhotoReviewDecision == 'approved');

    bloc.add(
      ProfilePhotoReviewNavigationConsumed(userId: uid, authRevision: revision),
    );

    await _waitUntil(
      () =>
          bloc.state.pendingPhotoReviewDecision == null &&
          bloc.state.pendingPhotoReviewUserId == null &&
          bloc.state.pendingPhotoReviewAuthRevision == null,
    );

    expect(bloc.state.user.id, uid);
  });

  test('13.6I - cambio de cuenta descarta la fotografía pendiente', () async {
    const firstUid = 'photo-student-A';
    const secondUid = 'photo-student-B';

    final firstRevision = await signInPhotoStudent(firstUid);

    bloc.add(
      ProfilePhotoReviewNotificationOpened(
        decision: 'approved',
        userId: firstUid,
        authRevision: firstRevision,
      ),
    );

    await _waitUntil(() => bloc.state.pendingPhotoReviewDecision == 'approved');

    users.changes.add(const User(id: secondUid, isNewUser: false));

    await _waitUntil(() => (profiles.requests[secondUid]?.length ?? 0) == 1);

    profiles.requests[secondUid]![0].complete(
      _profile(secondUid, 'Estudiante B'),
    );

    await _waitUntil(
      () =>
          bloc.state.user.id == secondUid &&
          bloc.state.institutionalProfile?.uid == secondUid,
    );

    expect(bloc.authRevision, isNot(firstRevision));
    expect(bloc.state.pendingPhotoReviewDecision, isNull);
    expect(bloc.state.pendingPhotoReviewUserId, isNull);
    expect(bloc.state.pendingPhotoReviewAuthRevision, isNull);

    // Una notificación tardía de A tampoco debe reactivarse.
    bloc.add(
      ProfilePhotoReviewNotificationOpened(
        decision: 'approved',
        userId: firstUid,
        authRevision: firstRevision,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.user.id, secondUid);
    expect(bloc.state.pendingPhotoReviewDecision, isNull);
  });

  // ============================================================
  // CORRECCIÓN 13.6J
  // Callback real de interacción con notificaciones locales.
  // ============================================================

  Future<void Function(Map<String, dynamic>)> preparePhotoTap(
    String uid,
  ) async {
    await bloc.close();

    void Function(Map<String, dynamic>)? onTap;

    bloc = AppBloc(
      firebaseMessaging: _TestMessaging(),
      userRepository: users,
      appUserProfileRepository: profiles,
      user: User.anonymous,
      academicCleanupService: _RecordingAcademicCleanup(),
      initializeLocalNotifications: (handler) async {
        onTap = handler;
      },
      configureRemoteMessaging: () async {},
    );

    bloc.add(const AppOpened());

    await _waitUntil(() => onTap != null);
    await signInPhotoStudent(uid);

    return onTap!;
  }

  test('13.6J - toque local de fotografía aprobada', () async {
    const uid = 'photo-tap-A';
    final onTap = await preparePhotoTap(uid);

    onTap({
      'type': 'profile_photo_review',
      'user_id': uid,
      'decision': 'approved',
      'submission_id': 'submission-ficticia',
    });

    await _waitUntil(() => bloc.state.pendingPhotoReviewDecision == 'approved');

    expect(bloc.state.pendingPhotoReviewUserId, uid);
    expect(bloc.state.pendingPhotoReviewAuthRevision, bloc.authRevision);
    expect(bloc.state.pendingAnnouncementId, isNull);
  });

  test('13.6J - toque local de fotografía rechazada', () async {
    const uid = 'photo-tap-A';
    final onTap = await preparePhotoTap(uid);

    onTap({
      'type': 'profile_photo_review',
      'user_id': uid,
      'decision': 'rejected',
      'submission_id': 'submission-ficticia',
    });

    await _waitUntil(() => bloc.state.pendingPhotoReviewDecision == 'rejected');

    expect(bloc.state.pendingPhotoReviewUserId, uid);
    expect(bloc.state.pendingAnnouncementId, isNull);
  });

  test('13.6J - toque local de otra cuenta se ignora', () async {
    const uid = 'photo-tap-A';
    final onTap = await preparePhotoTap(uid);

    onTap({
      'type': 'profile_photo_review',
      'user_id': 'photo-tap-B',
      'decision': 'approved',
    });

    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(bloc.state.user.id, uid);
    expect(bloc.state.pendingPhotoReviewDecision, isNull);
    expect(bloc.state.pendingPhotoReviewUserId, isNull);
    expect(bloc.state.pendingAnnouncementId, isNull);
  });
}
