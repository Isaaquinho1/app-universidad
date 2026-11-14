import 'dart:async';

/// Permite a una operación comprobar si su sesión sigue vigente.
class AcademicReminderOperationLease {
  AcademicReminderOperationLease._(this._isCurrent);

  final bool Function() _isCurrent;

  bool get isCurrent => _isCurrent();

  void ensureCurrent() {
    if (!isCurrent) {
      throw StateError(
        'La sesión del recordatorio académico ya no está vigente.',
      );
    }
  }
}

/// Serializa operaciones que afectan a las alarmas académicas.
///
/// Todas las operaciones que modifiquen alarmas deben utilizar
/// esta misma instancia. No abre SQLite ni ejecuta acciones
/// sobre notificaciones por sí mismo.
class AcademicReminderOperationCoordinator {
  String? _activeUserId;
  int _revision = -1;
  Future<void> _tail = Future<void>.value();

  String? get activeUserId => _activeUserId;
  int get revision => _revision;

  /// Se llama sincrónicamente cuando cambia la autenticación.
  void updateSession({required String? userId, required int revision}) {
    if (revision < 0 || revision < _revision) {
      throw ArgumentError.value(revision, 'revision');
    }

    final normalized = userId?.trim();

    _activeUserId =
        normalized == null || normalized.isEmpty ? null : normalized;
    _revision = revision;
  }

  bool isCurrent({required String userId, required int revision}) {
    return userId.trim().isNotEmpty &&
        _activeUserId == userId &&
        _revision == revision;
  }

  /// Devuelve false si la operación quedó obsoleta o se omitió.
  ///
  /// No interrumpe por la fuerza una operación en curso:
  /// el callback debe usar lease.ensureCurrent() después de
  /// cada await y antes de cualquier nueva acción externa.
  ///
  /// La cola impide que una operación posterior comience
  /// antes de que finalice la operación anterior.
  Future<bool> run({
    required String userId,
    required int revision,
    required Future<void> Function(AcademicReminderOperationLease lease)
    operation,
  }) {
    final result = Completer<bool>();
    final previous = _tail;

    _tail = _execute(
      previous: previous,
      userId: userId,
      revision: revision,
      operation: operation,
      result: result,
    );

    return result.future;
  }

  Future<void> _execute({
    required Future<void> previous,
    required String userId,
    required int revision,
    required Future<void> Function(AcademicReminderOperationLease lease)
    operation,
    required Completer<bool> result,
  }) async {
    try {
      await previous;

      if (!isCurrent(userId: userId, revision: revision)) {
        result.complete(false);
        return;
      }

      final lease = AcademicReminderOperationLease._(
        () => isCurrent(userId: userId, revision: revision),
      );

      await operation(lease);

      result.complete(lease.isCurrent);
    } catch (error, stackTrace) {
      result.completeError(error, stackTrace);
    }
  }

  /// Permite esperar hasta que la cola quede vacía.
  Future<void> get idle => _tail;
}
