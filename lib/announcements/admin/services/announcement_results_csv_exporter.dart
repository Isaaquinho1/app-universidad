import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';

class AnnouncementResultsCsvExporter {
  const AnnouncementResultsCsvExporter();

  Future<File> export({
    required AnnouncementResults results,
    required AnnouncementNotificationMetrics notificationMetrics,
    required List<AnnouncementResultRecipient> recipients,
    required String filterLabel,
    required String searchQuery,
  }) async {
    final directory = await getTemporaryDirectory();
    final fileName = _buildFileName(results);
    final file = File('${directory.path}/$fileName');

    final csv = _buildCsv(
      results: results,
      notificationMetrics: notificationMetrics,
      recipients: recipients,
      filterLabel: filterLabel,
      searchQuery: searchQuery,
    );

    // UTF-8 BOM improves compatibility with Excel and accented characters.
    await file.writeAsBytes(<int>[
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(csv),
    ], flush: true);

    return file;
  }

  String _buildCsv({
    required AnnouncementResults results,
    required AnnouncementNotificationMetrics notificationMetrics,
    required List<AnnouncementResultRecipient> recipients,
    required String filterLabel,
    required String searchQuery,
  }) {
    final rows = <List<Object?>>[
      const ['REPORTE DE RESULTADOS DEL COMUNICADO'],
      const [],
      ['Título', results.title],
      ['Identificador', results.announcementId],
      ['Estado', _announcementStatusLabel(results.status)],
      ['Versión del contenido', results.contentVersion],
      ['Publicado el', _formatDate(results.publishedAt)],
      ['Última actualización', _formatDate(results.updatedAt)],
      const [],
      const ['RESUMEN DE TRAZABILIDAD'],
      ['Audiencia total', results.summary.audienceTotal],
      ['Pendientes', results.summary.pending],
      ['Editados', results.summary.edited],
      ['Entregados', results.summary.delivered],
      ['Vistos', results.summary.seen],
      ['Leídos', results.summary.read],
      ['Confirmados', results.summary.confirmed],
      const [],
      const ['MÉTRICAS DE NOTIFICACIÓN PUSH'],
      ['Envío solicitado', notificationMetrics.wasRequested ? 'Sí' : 'No'],
      [
        'Estado del envío',
        _notificationStatusLabel(notificationMetrics.status),
      ],
      ['Versión enviada', notificationMetrics.contentVersion],
      ['Audiencia procesada', notificationMetrics.audienceCount],
      ['Tokens encontrados', notificationMetrics.tokenCount],
      ['Notificaciones enviadas', notificationMetrics.sentCount],
      ['Envíos fallidos', notificationMetrics.failedCount],
      ['Usuarios sin token', notificationMetrics.noTokenCount],
      ['Tokens inválidos', notificationMetrics.invalidTokenCount],
      [
        'Tasa de envío exitoso',
        '${(notificationMetrics.successRate * 100).toStringAsFixed(2)} %',
      ],
      ['Inicio del envío', _formatDate(notificationMetrics.startedAt)],
      ['Finalización del envío', _formatDate(notificationMetrics.completedAt)],
      ['Error del servidor', notificationMetrics.errorMessage ?? ''],
      const [],
      const ['CRITERIOS DE EXPORTACIÓN'],
      ['Filtro de estado', filterLabel],
      ['Texto de búsqueda', searchQuery.trim()],
      ['Destinatarios exportados', recipients.length],
      ['Fecha de generación', _formatDate(DateTime.now())],
      const [],
      const ['DETALLE DE DESTINATARIOS'],
      const [
        'Nombre',
        'Correo',
        'Número de control',
        'Rol',
        'Carrera',
        'Semestre',
        'Grupo',
        'Estado',
        'Versión recibida',
        'Entregado el',
        'Visto el',
        'Leído el',
        'Confirmado el',
        'Última actividad',
      ],
      ...recipients.map(
        (recipient) => <Object?>[
          recipient.displayName ?? '',
          recipient.email ?? '',
          recipient.controlNumber ?? '',
          _roleLabel(recipient.role),
          _careerLabel(recipient.careerId),
          recipient.semester ?? '',
          recipient.groupId?.toUpperCase() ?? '',
          _recipientStatusLabel(recipient.status),
          recipient.receiptVersion ?? '',
          _formatDate(recipient.deliveredAt),
          _formatDate(recipient.seenAt),
          _formatDate(recipient.readAt),
          _formatDate(recipient.confirmedAt),
          _formatDate(recipient.lastActivity),
        ],
      ),
    ];

    return rows.map(_encodeRow).join('\r\n');
  }

  String _buildFileName(AnnouncementResults results) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeTitle = _sanitizeFileName(results.title);

    return 'resultados_${safeTitle}_v'
        '${results.contentVersion}_$timestamp.csv';
  }

  String _sanitizeFileName(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (normalized.isEmpty) {
      return 'comunicado';
    }

    const maximumLength = 60;

    return normalized.length <= maximumLength
        ? normalized
        : normalized.substring(0, maximumLength);
  }

  String _encodeRow(List<Object?> values) {
    return values.map(_encodeCell).join(',');
  }

  String _encodeCell(Object? value) {
    final text = value?.toString() ?? '';

    // Prevent spreadsheet formula injection from user-controlled values.
    final safeText = RegExp(r'^[=+\-@]').hasMatch(text) ? "'$text" : text;

    if (safeText.contains(',') ||
        safeText.contains('"') ||
        safeText.contains('\n') ||
        safeText.contains('\r')) {
      return '"${safeText.replaceAll('"', '""')}"';
    }

    return safeText;
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }

    return DateFormat('dd/MM/yyyy HH:mm:ss', 'es_MX').format(value.toLocal());
  }

  String _careerLabel(String? careerId) {
    if (careerId == null || careerId.trim().isEmpty) {
      return '';
    }

    return InstitutionalCareers.labelFor(careerId);
  }

  String _roleLabel(String? role) {
    return switch (role) {
      'student' => 'Estudiante',
      'admin' => 'Administrador',
      'superAdmin' => 'Superadministrador',
      'super_admin' => 'Superadministrador',
      null || '' => '',
      _ => role,
    };
  }

  String _announcementStatusLabel(String status) {
    return switch (status) {
      'draft' => 'Borrador',
      'scheduled' => 'Programado',
      'published' => 'Publicado',
      'archived' => 'Archivado',
      _ => status,
    };
  }

  String _notificationStatusLabel(String status) {
    return switch (status) {
      'not_requested' => 'No solicitado',
      'processing' => 'Procesando',
      'completed' => 'Completado',
      'failed' => 'Fallido',
      _ => status,
    };
  }

  String _recipientStatusLabel(String status) {
    return switch (status) {
      'pending' => 'Pendiente',
      'edited' => 'Editado',
      'delivered' => 'Entregado',
      'seen' => 'Visto',
      'read' => 'Leído',
      'confirmed' => 'Confirmado',
      _ => status,
    };
  }
}
