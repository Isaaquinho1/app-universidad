import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:rtu_mirea_app/announcements/announcements.dart';
import 'package:rtu_mirea_app/app/app.dart';

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

  Future<void> _publish(Announcement announcement) async {
    final confirmed = await _confirmAction(
      title: 'Publicar comunicado',
      message:
          'El comunicado "${announcement.title}" será visible para su audiencia.',
      confirmText: 'Publicar',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runAction(
      successMessage: 'Comunicado publicado correctamente.',
      action:
          () => context.read<AnnouncementRepository>().publishAnnouncement(
            announcement.id,
          ),
    );
  }

  Future<void> _archive(Announcement announcement) async {
    final confirmed = await _confirmAction(
      title: 'Archivar comunicado',
      message:
          'El comunicado "${announcement.title}" dejará de mostrarse '
          'a los estudiantes.',
      confirmText: 'Archivar',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runAction(
      successMessage: 'Comunicado archivado correctamente.',
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

      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('No se pudo completar la operación: $error');
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!profile.canManageAnnouncements) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de comunicados')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xlg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64),
                SizedBox(height: AppSpacing.md),
                Text(
                  'No tienes permisos para administrar comunicados.',
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
        title: const Text('Gestión de comunicados'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: SizedBox(
              width: 40,
              height: 40,
              child: FilledButton(
                onPressed:
                    _isProcessing
                        ? null
                        : () => context.go(
                          '/profile/announcement-management/create',
                        ),
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
                          'No se pudieron cargar los comunicados.\n'
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
                        onPublish: () => _publish(announcement),
                        onArchive: () => _archive(announcement),
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
    required this.onPublish,
    required this.onArchive,
  });

  final Announcement announcement;
  final bool isProcessing;
  final VoidCallback onPublish;
  final VoidCallback onArchive;

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
                  label: Text(
                    'Prioridad: ${_priorityLabel(announcement.priority)}',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.groups_outlined, size: 18),
                  label: Text(
                    announcement.target.allUsers
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
                    onPressed:
                        isProcessing
                            ? null
                            : () => context.go(
                              '/profile/announcement-management/'
                              '${announcement.id}/edit',
                            ),
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
            if (announcement.status == AnnouncementStatus.published ||
                announcement.status == AnnouncementStatus.archived) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed:
                      isProcessing
                          ? null
                          : () => context.go(
                            '/profile/announcement-management/'
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
            ? 'Todavía no hay comunicados administrativos.'
            : 'No hay comunicados con estado '
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
