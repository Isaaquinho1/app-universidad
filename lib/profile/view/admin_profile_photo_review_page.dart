import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:conecta_itt/profile/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Administrative queue for reviewing institutional student photographs.
class AdminProfilePhotoReviewPage extends StatefulWidget {
  const AdminProfilePhotoReviewPage({super.key});

  @override
  State<AdminProfilePhotoReviewPage> createState() =>
      _AdminProfilePhotoReviewPageState();
}

class _AdminProfilePhotoReviewPageState
    extends State<AdminProfilePhotoReviewPage> {
  ProfilePhotoReviewFilter _selectedFilter = ProfilePhotoReviewFilter.pending;

  late Future<List<AppUserProfile>> _queueFuture;
  final Set<String> _processingProfileIds = <String>{};

  @override
  void initState() {
    super.initState();
    _queueFuture = _loadQueue();
  }

  Future<List<AppUserProfile>> _loadQueue() {
    return context.read<AdminProfilePhotoRepository>().fetchReviewQueue(
      filter: _selectedFilter,
    );
  }

  Future<void> _refresh() async {
    final future = _loadQueue();

    setState(() {
      _queueFuture = future;
    });

    await future;
  }

  void _selectFilter(ProfilePhotoReviewFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() {
      _selectedFilter = filter;
      _queueFuture = _loadQueue();
    });
  }

  Future<void> _approve(AppUserProfile profile) async {
    final confirmed = await _confirmAction(
      title: 'Aprobar fotografía',
      message:
          'La fotografía de ${_displayName(profile)} será validada '
          'para su identificación digital.',
      confirmLabel: 'Aprobar',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runReview(
      profile: profile,
      successMessage: 'Fotografía aprobada correctamente.',
      action:
          () => context.read<AdminProfilePhotoRepository>().approvePhoto(
            profileId: profile.uid,
          ),
    );
  }

  Future<void> _reject(AppUserProfile profile) async {
    final reason = await _requestRejectionReason(profile);

    if (reason == null || !mounted) {
      return;
    }

    await _runReview(
      profile: profile,
      successMessage: 'Fotografía rechazada correctamente.',
      action:
          () => context.read<AdminProfilePhotoRepository>().rejectPhoto(
            profileId: profile.uid,
            reason: reason,
          ),
    );
  }

  Future<void> _runReview({
    required AppUserProfile profile,
    required String successMessage,
    required Future<AppUserProfile> Function() action,
  }) async {
    if (_processingProfileIds.contains(profile.uid)) {
      return;
    }

    setState(() {
      _processingProfileIds.add(profile.uid);
    });

    try {
      await action();

      if (!mounted) {
        return;
      }

      await _showMessage(title: 'Revisión completada', message: successMessage);

      if (mounted) {
        await _refresh();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showMessage(
        title: 'No se pudo completar la revisión',
        message: error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingProfileIds.remove(profile.uid);
        });
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  Future<String?> _requestRejectionReason(AppUserProfile profile) {
    return showDialog<String>(
      context: context,
      builder:
          (dialogContext) =>
              _RejectionReasonDialog(studentName: _displayName(profile)),
    );
  }

  Future<void> _showMessage({required String title, required String message}) {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Aceptar'),
              ),
            ],
          ),
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
        appBar: AppBar(title: const Text('Revisión de fotografías')),
        body: const _UnauthorizedState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de fotografías'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ReviewFilters(
              selectedFilter: _selectedFilter,
              onSelected: _selectFilter,
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<AppUserProfile>>(
                future: _queueFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError && !snapshot.hasData) {
                    return _ErrorState(
                      message:
                          'No se pudo cargar la cola de revisión.\n'
                          '${snapshot.error}',
                      onRetry: _refresh,
                    );
                  }

                  final profiles = snapshot.data ?? const <AppUserProfile>[];

                  if (profiles.isEmpty) {
                    return _EmptyState(filter: _selectedFilter);
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        104,
                      ),
                      itemCount: profiles.length,
                      separatorBuilder:
                          (_, _) => const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) {
                        final studentProfile = profiles[index];

                        return _ReviewCard(
                          profile: studentProfile,
                          processing: _processingProfileIds.contains(
                            studentProfile.uid,
                          ),
                          onApprove:
                              studentProfile.isProfilePhotoPending
                                  ? () => _approve(studentProfile)
                                  : null,
                          onReject:
                              studentProfile.isProfilePhotoPending
                                  ? () => _reject(studentProfile)
                                  : null,
                        );
                      },
                    ),
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

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog({required this.studentName});

  final String studentName;

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedReason = _controller.text.trim();

    final canSubmit =
        normalizedReason.isNotEmpty && normalizedReason.length <= 500;

    return AlertDialog(
      title: const Text('Rechazar fotografía'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Indica por qué la fotografía de '
            '${widget.studentName} no cumple los requisitos.',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo del rechazo',
              hintText:
                  'Ejemplo: el rostro no se distingue '
                  'con claridad.',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              canSubmit
                  ? () => Navigator.of(context).pop(normalizedReason)
                  : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}

class _ReviewFilters extends StatelessWidget {
  const _ReviewFilters({
    required this.selectedFilter,
    required this.onSelected,
  });

  final ProfilePhotoReviewFilter selectedFilter;
  final ValueChanged<ProfilePhotoReviewFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: ProfilePhotoReviewFilter.values
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  selected: selectedFilter == filter,
                  label: Text(_filterLabel(filter)),
                  onSelected: (_) => onSelected(filter),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.profile,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final AppUserProfile profile;
  final bool processing;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _displayName(profile);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentProfilePhoto(
                  profile: profile,
                  initials: _initials(displayName),
                  width: 100,
                  height: 125,
                  borderRadius: BorderRadius.circular(18),
                  initialsStyle: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        profile.email ?? 'Correo institucional no disponible',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PhotoStatusChip(status: profile.photoStatus),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            _DataRow(
              label: 'Número de control',
              value: _valueOrFallback(profile.controlNumber),
            ),
            _DataRow(
              label: 'Carrera',
              value:
                  profile.careerId == null
                      ? 'No registrada'
                      : InstitutionalCareers.labelFor(profile.careerId!),
            ),
            _DataRow(
              label: 'Semestre',
              value:
                  profile.semester == null
                      ? 'No registrado'
                      : '${profile.semester}.º',
            ),
            _DataRow(
              label: 'Grupo',
              value: _valueOrFallback(profile.groupId).toUpperCase(),
            ),
            _DataRow(
              label: 'Enviada',
              value: _formatDate(profile.photoUpdatedAt),
            ),
            if (profile.isProfilePhotoRejected &&
                profile.photoRejectionReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  profile.photoRejectionReason!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: processing ? null : onReject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: processing ? null : onApprove,
                      icon:
                          processing
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.check_rounded),
                      label: Text(processing ? 'Procesando' : 'Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStatusChip extends StatelessWidget {
  const _PhotoStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, icon, background, foreground) = switch (status) {
      'approved' => (
        'Aprobada',
        Icons.verified_rounded,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      'rejected' => (
        'Rechazada',
        Icons.cancel_rounded,
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      _ => (
        'Pendiente',
        Icons.schedule_rounded,
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _UnauthorizedState extends StatelessWidget {
  const _UnauthorizedState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 64),
            SizedBox(height: AppSpacing.md),
            Text(
              'No tienes permisos para revisar fotografías.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final ProfilePhotoReviewFilter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 68),
            const SizedBox(height: AppSpacing.md),
            Text(
              filter == ProfilePhotoReviewFilter.pending
                  ? 'No hay fotografías pendientes.'
                  : 'No hay fotografías en este estado.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _filterLabel(ProfilePhotoReviewFilter filter) {
  return switch (filter) {
    ProfilePhotoReviewFilter.pending => 'Pendientes',
    ProfilePhotoReviewFilter.approved => 'Aprobadas',
    ProfilePhotoReviewFilter.rejected => 'Rechazadas',
    ProfilePhotoReviewFilter.all => 'Todas',
  };
}

String _displayName(AppUserProfile profile) {
  final displayName = profile.displayName?.trim();

  if (displayName != null && displayName.isNotEmpty) {
    return displayName;
  }

  return profile.email?.split('@').first ?? 'Estudiante';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'E';
  }

  return parts.map((part) => part[0].toUpperCase()).join();
}

String _valueOrFallback(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty
      ? 'No registrado'
      : normalized;
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) {
    return 'Fecha no disponible';
  }

  return DateFormat(
    "dd/MM/yyyy 'a las' HH:mm",
    'es_MX',
  ).format(dateTime.toLocal());
}
