/// {@template notification_exception}
/// Excepción del cliente de notificaciones.
/// {@endtemplate}
abstract class NotificationException implements Exception {
  /// {@macro notification_exception}
  const NotificationException(this.error);

  /// Error asociado.
  final Object error;
}

/// {@template subscribe_to_category_failure}
/// Se produce cuando falla la suscripción a una categoría.
/// {@endtemplate}
class SubscribeToCategoryFailure extends NotificationException {
  /// {@macro subscribe_to_category_failure}
  const SubscribeToCategoryFailure(super.error);
}

/// {@template unsubscribe_from_category_failure}
/// Se produce cuando falla la cancelación de una suscripción.
/// {@endtemplate}
class UnsubscribeFromCategoryFailure extends NotificationException {
  /// {@macro unsubscribe_from_category_failure}
  const UnsubscribeFromCategoryFailure(super.error);
}

/// {@template notifications_client}
/// Interfaz para gestionar suscripciones de notificaciones.
/// {@endtemplate}
abstract class NotificationsClient {
  /// Suscribe al usuario a las notificaciones de [category].
  Future<void> subscribeToCategory(String category);

  /// Cancela la suscripción del usuario a [category].
  Future<void> unsubscribeFromCategory(String category);
}
