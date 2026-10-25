import 'package:permission_handler/permission_handler.dart';

export 'package:permission_handler/permission_handler.dart'
    show PermissionStatus, PermissionStatusGetters;

/// {@template permission_client}
/// Cliente para solicitar permisos del dispositivo.
/// {@endtemplate}
class PermissionClient {
  /// {@macro permission_client}
  const PermissionClient();

  /// Solicita permiso para recibir notificaciones,
  /// si todavía no se ha concedido.
  Future<PermissionStatus> requestNotifications() =>
      Permission.notification.request();

  /// Devuelve el estado del permiso de notificaciones.
  Future<PermissionStatus> notificationsStatus() =>
      Permission.notification.status;

  /// Abre la configuración de la aplicación.
  ///
  /// Devuelve `true` si se abrió la configuración.
  Future<bool> openPermissionSettings() => openAppSettings();
}
