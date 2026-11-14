import 'dart:async';

import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/repositories/repositories.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_operation_coordinator.dart';
import 'package:conecta_itt/academic_planner/services/academic_reminder_restoration_service.dart';
import 'package:conecta_itt/academic_planner/services/academic_task_reminder_service.dart';
import 'package:conecta_itt/academic_planner/services/class_session_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TasksRepository implements AcademicTaskRepository {
  int reads = 0;
  Future<List<AcademicTask>> response = Future<List<AcademicTask>>.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getAll) {
      reads++;
      return response;
    }
    return super.noSuchMethod(invocation);
  }
}

class _SubjectsRepository implements AcademicSubjectRepository {
  int reads = 0;
  Future<List<AcademicSubject>> response = Future<List<AcademicSubject>>.value(
    [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getAll) {
      reads++;
      return response;
    }
    return super.noSuchMethod(invocation);
  }
}

class _SessionsRepository implements ClassSessionRepository {
  int reads = 0;
  Future<List<ClassSession>> response = Future<List<ClassSession>>.value([]);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getAll) {
      reads++;
      return response;
    }
    return super.noSuchMethod(invocation);
  }
}

class _TaskReminders implements AcademicTaskReminderService {
  int restores = 0;
  bool fail = false;
  void Function()? onRestore;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #restore) {
      restores++;
      onRestore?.call();
      if (fail) {
        return Future<void>.error(
          StateError('Error simulado al restaurar tareas'),
        );
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _ClassReminders implements ClassSessionReminderService {
  int restores = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #restore) {
      restores++;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _RegisteredReadAccount implements AcademicAccountScope {
  int activeReads = 0;
  int completedReads = 0;

  @override
  Future<T> run<T>(Future<T> Function() operation) async {
    activeReads++;
    try {
      return await operation();
    } finally {
      activeReads--;
      completedReads++;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AcademicReminderOperationCoordinator coordinator;
  late _TasksRepository tasksRepository;
  late _SubjectsRepository subjectsRepository;
  late _SessionsRepository sessionsRepository;
  late _TaskReminders taskReminders;
  late _ClassReminders classReminders;

  AcademicReminderRestorationService service(String uid, int revision) {
    return AcademicReminderRestorationService(
      userId: uid,
      coordinator: coordinator,
      authRevision: revision,
      taskRepository: tasksRepository,
      subjectRepository: subjectsRepository,
      classSessionRepository: sessionsRepository,
      taskReminderService: taskReminders,
      classSessionReminderService: classReminders,
    );
  }

  setUp(() {
    coordinator = AcademicReminderOperationCoordinator();
    tasksRepository = _TasksRepository();
    subjectsRepository = _SubjectsRepository();
    sessionsRepository = _SessionsRepository();
    taskReminders = _TaskReminders();
    classReminders = _ClassReminders();
  });

  test('restauración registra lecturas en el ámbito', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final account = _RegisteredReadAccount();

    final restoration = AcademicReminderRestorationService(
      userId: 'A',
      account: account,
      coordinator: coordinator,
      authRevision: 1,
      taskRepository: tasksRepository,
      subjectRepository: subjectsRepository,
      classSessionRepository: sessionsRepository,
      taskReminderService: taskReminders,
      classSessionReminderService: classReminders,
    );

    await restoration.restore();

    expect(account.activeReads, 0);
    expect(account.completedReads, 1);
    expect(taskReminders.restores, 1);
    expect(classReminders.restores, 1);
  });

  test('lectura registrada termina al invalidarse la sesión', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final account = _RegisteredReadAccount();
    final pendingRead = Completer<List<AcademicTask>>();
    tasksRepository.response = pendingRead.future;

    final restoration = AcademicReminderRestorationService(
      userId: 'A',
      account: account,
      coordinator: coordinator,
      authRevision: 1,
      taskRepository: tasksRepository,
      subjectRepository: subjectsRepository,
      classSessionRepository: sessionsRepository,
      taskReminderService: taskReminders,
      classSessionReminderService: classReminders,
    );

    final operation = restoration.restore();
    final assertion = expectLater(operation, throwsStateError);

    expect(account.activeReads, 1);

    coordinator.updateSession(userId: 'B', revision: 2);

    pendingRead.complete([]);
    await assertion;

    expect(account.activeReads, 0);
    expect(account.completedReads, 1);
    expect(taskReminders.restores, 0);
    expect(classReminders.restores, 0);
  });

  test('restauración vigente procesa tareas y clases', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    await service('A', 1).restore();

    expect(tasksRepository.reads, 1);
    expect(subjectsRepository.reads, 1);
    expect(sessionsRepository.reads, 1);
    expect(taskReminders.restores, 1);
    expect(classReminders.restores, 1);
  });

  test('sesión obsoleta no consulta repositorios', () async {
    coordinator.updateSession(userId: 'B', revision: 2);

    await expectLater(service('A', 1).restore(), throwsStateError);

    expect(tasksRepository.reads, 0);
    expect(subjectsRepository.reads, 0);
    expect(sessionsRepository.reads, 0);
    expect(taskReminders.restores, 0);
    expect(classReminders.restores, 0);
  });

  test('cambio de cuenta durante SQLite impide restaurar', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final pendingRead = Completer<List<AcademicTask>>();
    tasksRepository.response = pendingRead.future;

    final operation = service('A', 1).restore();
    final assertion = expectLater(operation, throwsStateError);

    coordinator.updateSession(userId: 'B', revision: 2);
    pendingRead.complete([]);

    await assertion;

    expect(taskReminders.restores, 0);
    expect(classReminders.restores, 0);
  });

  test('A-B-A no reactiva una restauración anterior', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    final previous = service('A', 1);

    coordinator.updateSession(userId: 'B', revision: 2);
    coordinator.updateSession(userId: 'A', revision: 3);

    await expectLater(previous.restore(), throwsStateError);

    expect(tasksRepository.reads, 0);
    expect(subjectsRepository.reads, 0);
    expect(sessionsRepository.reads, 0);
    expect(taskReminders.restores, 0);
    expect(classReminders.restores, 0);

    await service('A', 3).restore();

    expect(tasksRepository.reads, 1);
    expect(subjectsRepository.reads, 1);
    expect(sessionsRepository.reads, 1);
    expect(taskReminders.restores, 1);
    expect(classReminders.restores, 1);
  });

  test('cambio de cuenta después de tareas impide restaurar clases', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    taskReminders.onRestore = () {
      coordinator.updateSession(userId: 'B', revision: 2);
    };

    await expectLater(service('A', 1).restore(), throwsStateError);

    expect(taskReminders.restores, 1);
    expect(classReminders.restores, 0);
  });

  test('error de repositorio se propaga', () async {
    coordinator.updateSession(userId: 'A', revision: 1);

    tasksRepository.response = Future<List<AcademicTask>>.error(
      StateError('Lectura simulada fallida'),
    );

    await expectLater(service('A', 1).restore(), throwsStateError);

    expect(taskReminders.restores, 0);
    expect(classReminders.restores, 0);
  });

  test('error de restauración no se oculta', () async {
    coordinator.updateSession(userId: 'A', revision: 1);
    taskReminders.fail = true;

    await expectLater(service('A', 1).restore(), throwsStateError);

    expect(taskReminders.restores, 1);
    expect(classReminders.restores, 0);
  });
}
