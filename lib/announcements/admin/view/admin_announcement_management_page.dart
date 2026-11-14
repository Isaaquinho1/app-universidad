import 'package:conecta_itt/announcements/admin/models/announcement_navigation_result.dart';
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/app/app.dart';

/// Diálogo compartido para resultados administrativos.
class AdminAnnouncementResultDialog extends StatelessWidget {
  const AdminAnnouncementResultDialog({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

// Activar únicamente tras validar y desplegar la eliminación segura.
const bool _draftDeletionEnabled = false;

class AdminAnnouncementManagementPage extends StatefulWidget {
  const AdminAnnouncementManagementPage({super.key});

  @override
  State<AdminAnnouncementManagementPage> createState() =>
      _AdminAnnouncementManagementPageState();
}

class _AdminAnnouncementManagementPageState
    extends State<AdminAnnouncementManagementPage> {
  AnnouncementStatus? _selectedStatus;
  bool _isProcessing = false;
  int _adminListRevision = 0;

  Future<void> _openEdit(Announcement announcement) async {
    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final navigationResult = await context.push<AnnouncementNavigationResult>(
        '/services/announcement-management/'
        '${announcement.id}/edit',
      );

      if (!mounted || navigationResult == null) {
        return;
      }

      setState(() {});

      await _showMessage(
        navigationResult.message,
        title: navigationResult.title,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openCreate() async {
    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final navigationResult = await context.push<AnnouncementNavigationResult>(
        '/services/announcement-management/create',
      );

      if (!mounted || navigationResult == null) {
        return;
      }

      setState(() {});

      await _showMessage(
        navigationResult.message,
        title: navigationResult.title,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _publish(Announcement announcement) async {
    final label = announcement.contentType.label.toLowerCase();
    final scope =
        announcement.isNews
            ? 'toda la comunidad activa'
            : announcement.target.allUsers
            ? 'toda la comunidad activa'
            : 'la audiencia seleccionada';

    final confirmed = await _confirmAction(
      title: 'Publicar $label',
      message: 'La $label "${announcement.title}" será visible para $scope.',
      confirmText: 'Publicar',
    );

    if (!confirmed || !mounted) {
      return;
    }

    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await context
          .read<AnnouncementRepository>()
          .publishAnnouncement(announcement);

      if (!mounted) {
        return;
      }

      final notificationIssue = result['notification_issue'] == true;
      final failedCount = (result['failed_count'] as num?)?.toInt() ?? 0;
      final sentCount = (result['sent_count'] as num?)?.toInt() ?? 0;

      if (notificationIssue) {
        await _showMessage(
          '${announcement.contentType.label} publicada correctamente '
          'en Supabase. Sin embargo, no se pudo confirmar el resultado '
          'del envío de notificaciones. Revisa las métricas del despacho '
          'antes de intentar cualquier reenvío.',
          title: 'Publicación guardada con advertencia',
        );
      } else if (failedCount > 0) {
        await _showMessage(
          '${announcement.contentType.label} publicada correctamente. '
          'FCM informó $sentCount envío(s) exitoso(s) y '
          '$failedCount envío(s) fallido(s). '
          'Consulta las métricas antes de intentar un reenvío.',
          title: 'Publicación guardada con advertencias',
        );
      } else {
        await _showMessage(
          '${announcement.contentType.label} publicada correctamente. '
          'El servicio de notificaciones terminó su procesamiento '
          'sin reportar envíos fallidos.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showMessage(
        'No se pudo confirmar la publicación: $error '
        'Actualiza el listado antes de intentar nuevamente.',
        title: 'Publicación no confirmada',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _deleteDraft(Announcement announcement) async {
    if (!_draftDeletionEnabled || _isProcessing) {
      return;
    }

    if (announcement.status != AnnouncementStatus.draft ||
        announcement.publishedAt != null) {
      return;
    }

    final confirmed = await _confirmAction(
      title: 'Eliminar borrador',
      message:
          '¿Eliminar definitivamente "${announcement.title}"? '
          'Esta acción no se puede deshacer. '
          'También se iniciará la limpieza de sus archivos asociados.',
      confirmText: 'Eliminar borrador',
    );

    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await context
          .read<AnnouncementRepository>()
          .deleteUnpublishedDraft(announcement.id);

      if (!mounted) {
        return;
      }

      final complete = result['storage_cleanup_complete'] == true;

      setState(() => _adminListRevision++);

      if (complete) {
        final deletedNow = result['deleted'] == true;

        await _showMessage(
          deletedNow
              ? 'Borrador eliminado y limpieza de archivos confirmada.'
              : 'La limpieza de archivos de una eliminación anterior '
                  'se completó correctamente.',
          title: deletedNow ? 'Borrador eliminado' : 'Limpieza completada',
        );
      } else {
        await _showMessage(
          'La eliminación fue aceptada, pero quedan archivos '
          'pendientes de limpieza. No repitas la operación '
          'sin revisar el estado del servidor.',
          title: 'Limpieza pendiente',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      // El servidor pudo completar la eliminación antes de
      // que el cliente perdiera la respuesta.
      setState(() => _adminListRevision++);

      await _showMessage(
        'No se pudo confirmar la eliminación del borrador. '
        'Consulta su estado antes de intentar nuevamente. '
        'Detalle: $error',
        title: 'Eliminación no confirmada',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _archive(Announcement announcement) async {
    final label = announcement.contentType.label.toLowerCase();

    final confirmed = await _confirmAction(
      title: 'Archivar $label',
      message:
          'La $label "${announcement.title}" dejará de mostrarse '
          'a los usuarios.',
      confirmText: 'Archivar',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runAction(
      successMessage:
          '${announcement.contentType.label} archivada correctamente.',
      action:
          () => context.read<AnnouncementRepository>().archiveAnnouncement(
            announcement.id,
          ),
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await action();

      if (!mounted) {
        return;
      }

      await _showMessage(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showMessage('No se pudo completar la operación: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showMessage(
    String message, {
    String title = 'Operación completada',
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder:
          (_) => AdminAnnouncementResultDialog(title: title, message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!profile.canManageAnnouncements) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de publicaciones')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xlg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64),
                SizedBox(height: AppSpacing.md),
                Text(
                  'No tienes permisos para administrar publicaciones.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de publicaciones'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: SizedBox(
              width: 40,
              height: 40,
              child: FilledButton(
                onPressed: _isProcessing ? null : _openCreate,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusFilters(
              selectedStatus: _selectedStatus,
              onSelected: (status) {
                setState(() => _selectedStatus = status);
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<Announcement>>(
                key: ValueKey(_adminListRevision),
                stream: context
                    .read<AnnouncementRepository>()
                    .watchAdminAnnouncements(status: _selectedStatus),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError && !snapshot.hasData) {
                    return _ErrorState(
                      message:
                          'No se pudieron cargar las publicaciones.\n'
                          '${snapshot.error}',
                      onRetry: () => setState(() {}),
                    );
                  }

                  final announcements = snapshot.data ?? const <Announcement>[];

                  if (announcements.isEmpty) {
                    return _EmptyState(status: _selectedStatus);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      104,
                    ),
                    itemCount: announcements.length,
                    separatorBuilder:
                        (_, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final announcement = announcements[index];

                      return _AnnouncementAdminCard(
                        announcement: announcement,
                        isProcessing: _isProcessing,
                        onEdit: () => _openEdit(announcement),
                        onPublish: () => _publish(announcement),
                        onArchive: () => _archive(announcement),
                        onDeleteDraft: () => _deleteDraft(announcement),
                        canDeleteDraft: _draftDeletionEnabled,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.selectedStatus,
    required this.onSelected,
  });

  final AnnouncementStatus? selectedStatus;
  final ValueChanged<AnnouncementStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Todos'),
            selected: selectedStatus == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final status in AnnouncementStatus.values) ...[
            ChoiceChip(
              label: Text(_statusLabel(status)),
              selected: selectedStatus == status,
              onSelected: (_) => onSelected(status),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _AnnouncementAdminCard extends StatelessWidget {
  const _AnnouncementAdminCard({
    required this.announcement,
    required this.isProcessing,
    required this.onEdit,
    required this.onPublish,
    required this.onArchive,
    required this.onDeleteDraft,
    required this.canDeleteDraft,
  });

  final Announcement announcement;
  final bool isProcessing;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onDeleteDraft;
  final bool canDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = announcement.summary?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                Chip(
                  avatar: Icon(_statusIcon(announcement.status), size: 18),
                  label: Text(_statusLabel(announcement.status)),
                ),
                Chip(
                  avatar: Icon(
                    announcement.isNews
                        ? Icons.newspaper_outlined
                        : Icons.campaign_outlined,
                    size: 18,
                  ),
                  label: Text(announcement.contentType.label),
                ),
                if (announcement.isAnnouncement)
                  Chip(
                    label: Text(
                      'Prioridad: ${_priorityLabel(announcement.priority)}',
                    ),
                  ),
                if (announcement.isNews &&
                    announcement.newsCategory?.trim().isNotEmpty == true)
                  Chip(
                    avatar: const Icon(Icons.sell_outlined, size: 18),
                    label: Text(announcement.newsCategory!.trim()),
                  ),
                if (announcement.isCurrentlyFeatured)
                  const Chip(
                    avatar: Icon(Icons.star_rounded, size: 18),
                    label: Text('Destacada'),
                  ),
                Chip(
                  avatar: Icon(
                    announcement.target.allUsers
                        ? Icons.public_outlined
                        : Icons.groups_outlined,
                    size: 18,
                  ),
                  label: Text(
                    announcement.isNews
                        ? 'Publicación global'
                        : announcement.target.allUsers
                        ? 'Toda la comunidad'
                        : 'Audiencia segmentada',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(announcement.title, style: theme.textTheme.titleLarge),
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(summary, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Autor: ${announcement.authorName ?? 'Administración Conecta ITT'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: isProcessing ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                if (announcement.status == AnnouncementStatus.draft ||
                    announcement.status == AnnouncementStatus.scheduled)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isProcessing ? null : onPublish,
                      icon: const Icon(Icons.publish_outlined),
                      label: const Text('Publicar'),
                    ),
                  ),
                if (announcement.status == AnnouncementStatus.published)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : onArchive,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archivar'),
                    ),
                  ),
              ],
            ),

            if (announcement.status == AnnouncementStatus.draft) ...[
              const SizedBox(height: AppSpacing.sm),
              Tooltip(
                message:
                    canDeleteDraft
                        ? 'Eliminar este borrador definitivamente'
                        : 'Disponible tras validar la seguridad del servidor',
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        isProcessing || !canDeleteDraft ? null : onDeleteDraft,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar borrador'),
                  ),
                ),
              ),
            ],
            if (announcement.isAnnouncement &&
                (announcement.status == AnnouncementStatus.published ||
                    announcement.status == AnnouncementStatus.archived)) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed:
                      isProcessing
                          ? null
                          : () => context.go(
                            '/services/announcement-management/'
                            '${announcement.id}/results',
                          ),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Ver resultados'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status});

  final AnnouncementStatus? status;

  @override
  Widget build(BuildContext context) {
    final description =
        status == null
            ? 'Todavía no hay publicaciones administrativas.'
            : 'No hay publicaciones con estado '
                '"${_statusLabel(status!)}".';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_outlined, size: 72),
            const SizedBox(height: AppSpacing.md),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(AnnouncementStatus status) {
  switch (status) {
    case AnnouncementStatus.draft:
      return 'Borradores';
    case AnnouncementStatus.scheduled:
      return 'Programados';
    case AnnouncementStatus.published:
      return 'Publicados';
    case AnnouncementStatus.archived:
      return 'Archivados';
  }
}

IconData _statusIcon(AnnouncementStatus status) {
  switch (status) {
    case AnnouncementStatus.draft:
      return Icons.edit_note_outlined;
    case AnnouncementStatus.scheduled:
      return Icons.schedule_outlined;
    case AnnouncementStatus.published:
      return Icons.public_outlined;
    case AnnouncementStatus.archived:
      return Icons.archive_outlined;
  }
}

String _priorityLabel(AnnouncementPriority priority) {
  switch (priority) {
    case AnnouncementPriority.low:
      return 'baja';
    case AnnouncementPriority.normal:
      return 'normal';
    case AnnouncementPriority.high:
      return 'alta';
    case AnnouncementPriority.urgent:
      return 'urgente';
  }
}
