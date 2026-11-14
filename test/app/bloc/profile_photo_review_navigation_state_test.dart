import 'package:conecta_itt/app/bloc/app_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const studentId = 'estudiante-prueba-001';
  const otherStudentId = 'estudiante-prueba-002';

  AppState initialState() {
    return const AppState(status: AppStatus.authenticated);
  }

  group('Corrección 13.6F - Notificaciones de fotografías', () {
    test('01 - Sin notificación pendiente al iniciar', () {
      final state = initialState();

      expect(state.pendingPhotoReviewDecision, isNull);
      expect(state.pendingPhotoReviewUserId, isNull);
      expect(state.pendingPhotoReviewAuthRevision, isNull);
    });

    test('02 - Guarda fotografía aprobada y destinatario', () {
      final state = initialState().copyWith(
        pendingPhotoReviewDecision: 'approved',
        pendingPhotoReviewUserId: studentId,
        pendingPhotoReviewAuthRevision: 3,
      );

      expect(state.pendingPhotoReviewDecision, 'approved');
      expect(state.pendingPhotoReviewUserId, studentId);
      expect(state.pendingPhotoReviewAuthRevision, 3);
    });

    test('03 - Guarda fotografía rechazada', () {
      final state = initialState().copyWith(
        pendingPhotoReviewDecision: 'rejected',
        pendingPhotoReviewUserId: studentId,
        pendingPhotoReviewAuthRevision: 4,
      );

      expect(state.pendingPhotoReviewDecision, 'rejected');
      expect(state.pendingPhotoReviewUserId, studentId);
      expect(state.pendingPhotoReviewAuthRevision, 4);
    });

    test('04 - Consumir navegación limpia sus tres campos', () {
      final pending = initialState().copyWith(
        pendingPhotoReviewDecision: 'approved',
        pendingPhotoReviewUserId: studentId,
        pendingPhotoReviewAuthRevision: 5,
        pendingAnnouncementId: 'comunicado-prueba',
        pendingAcademicTaskId: 'tarea-prueba',
      );

      final consumed = pending.copyWith(clearPendingPhotoReview: true);

      expect(consumed.pendingPhotoReviewDecision, isNull);
      expect(consumed.pendingPhotoReviewUserId, isNull);
      expect(consumed.pendingPhotoReviewAuthRevision, isNull);

      // La limpieza no debe borrar otros tipos de avisos.
      expect(consumed.pendingAnnouncementId, 'comunicado-prueba');
      expect(consumed.pendingAcademicTaskId, 'tarea-prueba');
    });

    test('05 - Reemplazar una notificación actualiza el estado', () {
      final first = initialState().copyWith(
        pendingPhotoReviewDecision: 'approved',
        pendingPhotoReviewUserId: studentId,
        pendingPhotoReviewAuthRevision: 1,
      );

      final second = first.copyWith(
        pendingPhotoReviewDecision: 'rejected',
        pendingPhotoReviewUserId: otherStudentId,
        pendingPhotoReviewAuthRevision: 2,
      );

      expect(second.pendingPhotoReviewDecision, 'rejected');
      expect(second.pendingPhotoReviewUserId, otherStudentId);
      expect(second.pendingPhotoReviewAuthRevision, 2);
      expect(second, isNot(first));
    });

    test('06 - Evento de apertura conserva la identidad', () {
      const event = ProfilePhotoReviewNotificationOpened(
        decision: 'approved',
        userId: studentId,
        authRevision: 7,
      );

      expect(event.decision, 'approved');
      expect(event.userId, studentId);
      expect(event.authRevision, 7);
      expect(event.props, ['approved', studentId, 7]);
    });

    test('07 - Evento de consumo conserva la sesión', () {
      const event = ProfilePhotoReviewNavigationConsumed(
        userId: studentId,
        authRevision: 8,
      );

      expect(event.userId, studentId);
      expect(event.authRevision, 8);
      expect(event.props, [studentId, 8]);
    });
  });
}
