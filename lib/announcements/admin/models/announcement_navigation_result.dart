/// Resultado enviado del formulario al panel administrativo.
enum AnnouncementNavigationStatus { success, notificationWarning }

class AnnouncementNavigationResult {
  const AnnouncementNavigationResult({
    required this.message,
    required this.status,
  });

  final String message;
  final AnnouncementNavigationStatus status;

  bool get hasWarning =>
      status == AnnouncementNavigationStatus.notificationWarning;

  String get title =>
      hasWarning
          ? 'Publicación guardada con advertencia'
          : 'Operación completada';
}
