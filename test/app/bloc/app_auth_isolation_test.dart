import 'dart:async';

import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
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
    await bloc.close();
    await users.dispose();
    await profiles.dispose();
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

    bloc.add(const AcademicTaskNotificationOpened('task-A'));
    await _waitUntil(() => bloc.state.pendingAcademicTaskId == 'task-A');

    bloc.add(const AcademicTaskNotificationOpened('task-B'));
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
      const ClassSessionNotificationOpened(
        sessionId: 'session-A',
        subjectId: 'subject-A',
      ),
    );
    await _waitUntil(() => bloc.state.pendingClassSessionId == 'session-A');

    bloc.add(
      const ClassSessionNotificationOpened(
        sessionId: 'session-B',
        subjectId: 'subject-B',
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

    bloc.add(const AcademicTaskNotificationOpened('task-A'));
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
      const ClassSessionNotificationOpened(
        sessionId: 'session-A',
        subjectId: 'subject-A',
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
}
