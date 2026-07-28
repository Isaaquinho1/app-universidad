import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';

class AdminAnnouncementCreatePage extends StatefulWidget {
  const AdminAnnouncementCreatePage({super.key, this.initialAnnouncement});

  final Announcement? initialAnnouncement;

  @override
  State<AdminAnnouncementCreatePage> createState() =>
      _AdminAnnouncementCreatePageState();
}

class _AdminAnnouncementCreatePageState
    extends State<AdminAnnouncementCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _bodyController = TextEditingController();
  final _groupsController = TextEditingController();
  final _recipientSearchController = TextEditingController();

  AnnouncementPriority _priority = AnnouncementPriority.normal;
  bool _allUsers = true;
  bool _specificRecipients = false;
  bool _allSemesters = true;
  final Set<AppUserRole> _selectedRoles = {};
  final Set<String> _selectedCareerIds = {};
  final Set<int> _selectedSemesters = {};
  final Map<String, AnnouncementRecipient> _selectedRecipients = {};
  List<AnnouncementRecipient> _recipientSearchResults = const [];
  bool _isSearchingRecipients = false;
  String? _recipientSearchError;
  bool _isSubmitting = false;
  bool _isLoadingInitialRecipients = false;
  bool _hasChanges = false;
  bool _initialStateReady = false;

  List<PublicationAsset> _publicationAssets = const [];
  bool _isLoadingAssets = false;
  bool _isManagingAssets = false;
  String? _assetError;

  Announcement? _persistedAnnouncement;

  bool get _isEditing => _persistedAnnouncement != null;

  String? get _publicationId {
    final id = _persistedAnnouncement?.id.trim();

    if (id == null || id.isEmpty) {
      return null;
    }

    return id;
  }

  bool get _canManageAssets => _publicationId != null;

  @override
  void initState() {
    super.initState();

    _titleController.addListener(_evaluateChanges);
    _summaryController.addListener(_evaluateChanges);
    _bodyController.addListener(_evaluateChanges);
    _groupsController.addListener(_evaluateChanges);

    final announcement = widget.initialAnnouncement;
    _persistedAnnouncement = announcement;

    if (announcement == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPublicationAssets();
    });

    _titleController.text = announcement.title;
    _summaryController.text = announcement.summary ?? '';
    _bodyController.text = announcement.body;
    _groupsController.text = announcement.target.groupIds.join(', ');

    _priority = announcement.priority;
    _allUsers = announcement.target.allUsers;
    _specificRecipients = !_allUsers && announcement.target.userUids.isNotEmpty;
    _allSemesters = announcement.target.semesters.isEmpty;

    _selectedRoles.addAll(announcement.target.roles);
    _selectedCareerIds.addAll(announcement.target.careerIds);
    _selectedSemesters.addAll(announcement.target.semesters);

    if (announcement.target.userUids.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadInitialRecipients(announcement.target.userUids);

        if (!mounted) {
          return;
        }

        setState(() {
          _initialStateReady = true;
          _hasChanges = false;
        });
      });
    } else {
      _initialStateReady = true;
    }
  }

  Future<void> _loadInitialRecipients(Set<String> userUids) async {
    if (!mounted) {
      return;
    }

    setState(() => _isLoadingInitialRecipients = true);

    try {
      final recipients = await context
          .read<AnnouncementRepository>()
          .fetchRecipientsByIds(userUids);

      if (!mounted) {
        return;
      }

      setState(() {
        for (final recipient in recipients) {
          _selectedRecipients[recipient.uid] = recipient;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('No se pudieron cargar algunos destinatarios: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitialRecipients = false);
      }
    }
  }

  Future<void> _loadPublicationAssets() async {
    final publicationId = _publicationId;

    if (publicationId == null || !mounted) {
      return;
    }

    setState(() {
      _isLoadingAssets = true;
      _assetError = null;
    });

    try {
      final assets = await context
          .read<PublicationAssetRepository>()
          .fetchAssets(publicationId: publicationId);

      if (!mounted) {
        return;
      }

      setState(() {
        _publicationAssets = assets;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _assetError = 'No se pudieron cargar los archivos: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingAssets = false);
      }
    }
  }

  Future<void> _selectCover() async {
    final publicationId = _publicationId;

    if (publicationId == null || _isManagingAssets) {
      return;
    }

    final repository = context.read<PublicationAssetRepository>();
    final file = await repository.pickCoverImage();

    if (file == null || !mounted) {
      return;
    }

    final currentCover = _coverAsset;

    if (currentCover != null) {
      final confirmed = await _confirmAssetAction(
        title: 'Cambiar portada',
        message: 'La portada actual será sustituida por "${file.name}".',
        confirmText: 'Cambiar',
      );

      if (!confirmed || !mounted) {
        return;
      }
    }

    await _runAssetOperation(
      action: () async {
        if (currentCover == null) {
          await repository.uploadAsset(
            publicationId: publicationId,
            file: file,
            type: PublicationAssetType.cover,
          );
        } else {
          await repository.replaceCover(
            publicationId: publicationId,
            file: file,
          );
        }
      },
      successMessage:
          currentCover == null
              ? 'Portada agregada correctamente.'
              : 'Portada actualizada correctamente.',
    );
  }

  Future<void> _selectGalleryImages() async {
    final publicationId = _publicationId;

    if (publicationId == null || _isManagingAssets) {
      return;
    }

    final repository = context.read<PublicationAssetRepository>();
    final files = await repository.pickGalleryImages();

    if (files.isEmpty || !mounted) {
      return;
    }

    await _runAssetOperation(
      action: () async {
        final initialOrder = _galleryAssets.length;

        for (var index = 0; index < files.length; index++) {
          await repository.uploadAsset(
            publicationId: publicationId,
            file: files[index],
            type: PublicationAssetType.image,
            displayOrder: initialOrder + index,
          );
        }
      },
      successMessage:
          files.length == 1
              ? 'Imagen agregada correctamente.'
              : '${files.length} imágenes agregadas correctamente.',
    );
  }

  Future<void> _selectAttachments() async {
    final publicationId = _publicationId;

    if (publicationId == null || _isManagingAssets) {
      return;
    }

    final repository = context.read<PublicationAssetRepository>();
    final files = await repository.pickAttachments();

    if (files.isEmpty || !mounted) {
      return;
    }

    await _runAssetOperation(
      action: () async {
        final initialOrder = _attachmentAssets.length;

        for (var index = 0; index < files.length; index++) {
          await repository.uploadAsset(
            publicationId: publicationId,
            file: files[index],
            type: PublicationAssetType.attachment,
            displayOrder: initialOrder + index,
          );
        }
      },
      successMessage:
          files.length == 1
              ? 'Documento adjuntado correctamente.'
              : '${files.length} documentos adjuntados correctamente.',
    );
  }

  Future<void> _removeAsset(PublicationAsset asset) async {
    if (_isManagingAssets) {
      return;
    }

    final confirmed = await _confirmAssetAction(
      title:
          asset.type.isCover
              ? 'Eliminar portada'
              : asset.type.isImage
              ? 'Eliminar imagen'
              : 'Eliminar documento',
      message: 'Se eliminará permanentemente "${asset.originalName}".',
      confirmText: 'Eliminar',
      destructive: true,
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _runAssetOperation(
      action:
          () => context.read<PublicationAssetRepository>().deleteAsset(asset),
      successMessage: 'Archivo eliminado correctamente.',
    );
  }

  Future<void> _runAssetOperation({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_isManagingAssets) {
      return;
    }

    setState(() {
      _isManagingAssets = true;
      _assetError = null;
    });

    try {
      await action();
      await _loadPublicationAssets();

      if (!mounted) {
        return;
      }

      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _assetError = 'No se pudo completar la operación: $error';
      });

      _showMessage('No se pudo procesar el archivo: $error');
    } finally {
      if (mounted) {
        setState(() => _isManagingAssets = false);
      }
    }
  }

  Future<bool> _confirmAssetAction({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
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
              style:
                  destructive
                      ? FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(dialogContext).colorScheme.error,
                      )
                      : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  PublicationAsset? get _coverAsset {
    for (final asset in _publicationAssets) {
      if (asset.type.isCover) {
        return asset;
      }
    }

    return null;
  }

  List<PublicationAsset> get _galleryAssets {
    return _publicationAssets
        .where((asset) => asset.type == PublicationAssetType.image)
        .toList(growable: false);
  }

  List<PublicationAsset> get _attachmentAssets {
    return _publicationAssets
        .where((asset) => asset.type.isAttachment)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _groupsController.dispose();
    _recipientSearchController.dispose();
    super.dispose();
  }

  void _setFormState(VoidCallback mutation) {
    setState(mutation);
    _evaluateChanges();
  }

  void _evaluateChanges() {
    if (!_isEditing || !_initialStateReady || !mounted) {
      return;
    }

    final changed = !_matchesInitialAnnouncement();

    if (changed == _hasChanges) {
      return;
    }

    setState(() {
      _hasChanges = changed;
    });
  }

  bool _matchesInitialAnnouncement() {
    final initial = _persistedAnnouncement;

    if (initial == null) {
      return false;
    }

    final currentSummary = _summaryController.text.trim();

    return _titleController.text.trim() == initial.title.trim() &&
        _bodyController.text.trim() == initial.body.trim() &&
        (currentSummary.isEmpty ? null : currentSummary) ==
            initial.summary?.trim() &&
        _priority == initial.priority &&
        _targetsAreEqual(_buildTarget(), initial.target);
  }

  bool _targetsAreEqual(
    AnnouncementTarget current,
    AnnouncementTarget initial,
  ) {
    return current.allUsers == initial.allUsers &&
        _setsAreEqual(current.roles, initial.roles) &&
        _setsAreEqual(current.careerIds, initial.careerIds) &&
        _setsAreEqual(current.semesters, initial.semesters) &&
        _setsAreEqual(current.groupIds, initial.groupIds) &&
        _setsAreEqual(current.userUids, initial.userUids);
  }

  bool _setsAreEqual<T>(Set<T> first, Set<T> second) {
    return first.length == second.length && first.containsAll(second);
  }

  Future<bool> _confirmUpdate() async {
    final initial = _persistedAnnouncement;

    if (initial == null) {
      return true;
    }

    final isPublished = initial.status == AnnouncementStatus.published;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar actualización'),
          content: Text(
            isPublished
                ? 'Se creará una nueva versión del comunicado y se '
                    'enviará otra notificación push a los destinatarios.'
                : 'Se guardarán los cambios del comunicado. '
                    'No se enviará una notificación mientras no esté '
                    'publicado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _confirmDraftPublication() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Publicar comunicado'),
          content: const Text(
            'El comunicado se publicará para la audiencia seleccionada '
            'y se enviará una notificación push a sus destinatarios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Publicar'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<void> _submit({required bool publish}) async {
    if (_isSubmitting || _isManagingAssets) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      _showMessage('Revisa el título y el contenido del comunicado.');
      return;
    }

    if (!_allUsers &&
        !_specificRecipients &&
        !_allSemesters &&
        _selectedSemesters.isEmpty) {
      _showMessage(
        'Selecciona al menos un semestre o activa '
        '"Todos los semestres".',
      );
      return;
    }

    if (_specificRecipients && _selectedRecipients.isEmpty) {
      _showMessage('Selecciona al menos una persona específica.');
      return;
    }

    final target = _buildTarget();

    if (target.isEmpty) {
      _showMessage('Selecciona al menos un criterio de audiencia.');
      return;
    }

    final appState = context.read<AppBloc>().state;
    final profile = appState.institutionalProfile;

    if (profile == null || !profile.canManageAnnouncements) {
      _showMessage('No tienes permisos para crear comunicados.');
      return;
    }

    if (_isEditing) {
      final persisted = _persistedAnnouncement;
      final isPublishingDraft =
          publish && persisted?.status == AnnouncementStatus.draft;

      if (!_hasChanges && !isPublishingDraft) {
        return;
      }

      final confirmed =
          isPublishingDraft
              ? await _confirmDraftPublication()
              : await _confirmUpdate();

      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now().toUtc();
      final authorName = profile.displayName?.trim();

      final existingAnnouncement = _persistedAnnouncement;

      final nextStatus =
          publish
              ? AnnouncementStatus.published
              : existingAnnouncement?.status == AnnouncementStatus.published
              ? AnnouncementStatus.published
              : AnnouncementStatus.draft;

      final announcement = Announcement(
        id: existingAnnouncement?.id ?? '',
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        summary:
            _summaryController.text.trim().isEmpty
                ? null
                : _summaryController.text.trim(),
        authorUid: existingAnnouncement?.authorUid ?? profile.uid,
        authorName:
            existingAnnouncement?.authorName ??
            (authorName == null || authorName.isEmpty
                ? 'Administración Conecta ITT'
                : authorName),
        target: target,
        status: nextStatus,
        priority: _priority,
        createdAt: existingAnnouncement?.createdAt ?? now,
        updatedAt: now,
        publishedAt:
            nextStatus == AnnouncementStatus.published
                ? existingAnnouncement?.publishedAt ?? now
                : null,
        expiresAt: existingAnnouncement?.expiresAt,
        attachmentUrls: existingAnnouncement?.attachmentUrls ?? const [],
      );

      final repository = context.read<AnnouncementRepository>();

      final wasPersisted = _isEditing;
      late final String persistedId;

      if (wasPersisted) {
        await repository.updateAnnouncement(announcement);
        persistedId = announcement.id;
      } else {
        persistedId = await repository.createAnnouncement(announcement);
      }

      if (!mounted) {
        return;
      }

      final persistedAnnouncement = announcement.copyWith(id: persistedId);

      setState(() {
        _persistedAnnouncement = persistedAnnouncement;
        _hasChanges = false;
        _initialStateReady = true;
      });

      if (!publish) {
        _showMessage(
          wasPersisted
              ? 'Borrador actualizado correctamente.'
              : 'Borrador creado. Ya puedes agregar contenido multimedia.',
        );
        return;
      }

      final successMessage =
          wasPersisted
              ? 'Comunicado actualizado correctamente.'
              : 'Comunicado publicado correctamente.';

      Navigator.of(context).pop(successMessage);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('No se pudo guardar el comunicado: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Conecta ITT'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    ).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!profile.canManageAnnouncements) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar comunicado' : 'Crear comunicado'),
        ),
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
        title: Text(_isEditing ? 'Editar comunicado' : 'Crear comunicado'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej. Suspensión de actividades',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Escribe el título del comunicado.';
                  }

                  if (text.length < 5) {
                    return 'El título debe tener al menos 5 caracteres.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _summaryController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 240,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Resumen opcional',
                  hintText: 'Descripción breve para mostrar en el feed',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _bodyController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  hintText: 'Escribe el comunicado completo',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Escribe el contenido del comunicado.';
                  }

                  if (text.length < 20) {
                    return 'El contenido debe tener al menos 20 caracteres.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<AnnouncementPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Prioridad',
                  border: OutlineInputBorder(),
                ),
                items: AnnouncementPriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(_priorityLabel(priority)),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    _isSubmitting
                        ? null
                        : (priority) {
                          if (priority != null) {
                            _setFormState(() => _priority = priority);
                          }
                        },
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAudienceSection(context),
              const SizedBox(height: AppSpacing.lg),
              _buildMultimediaPreparationCard(context),
              const SizedBox(height: AppSpacing.xlg),
              if (_isEditing) ...[
                OutlinedButton.icon(
                  onPressed:
                      _isSubmitting ||
                              _isManagingAssets ||
                              _isLoadingInitialRecipients ||
                              !_initialStateReady ||
                              !_hasChanges
                          ? null
                          : () => _submit(publish: false),
                  icon:
                      _isSubmitting
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSubmitting ? 'Guardando cambios…' : 'Guardar cambios',
                  ),
                ),
                if (_persistedAnnouncement?.status ==
                    AnnouncementStatus.draft) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed:
                        _isSubmitting ||
                                _isManagingAssets ||
                                _isLoadingInitialRecipients ||
                                !_initialStateReady
                            ? null
                            : () => _submit(publish: true),
                    icon:
                        _isSubmitting
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.publish_outlined),
                    label: Text(
                      _isSubmitting ? 'Publicando…' : 'Publicar comunicado',
                    ),
                  ),
                ],
              ] else ...[
                OutlinedButton.icon(
                  onPressed:
                      _isSubmitting || _isManagingAssets
                          ? null
                          : () => _submit(publish: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar borrador'),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed:
                      _isSubmitting || _isManagingAssets
                          ? null
                          : () => _submit(publish: true),
                  icon:
                      _isSubmitting
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.publish_outlined),
                  label: Text(
                    _isSubmitting ? 'Publicando…' : 'Publicar comunicado',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultimediaPreparationCard(BuildContext context) {
    final theme = Theme.of(context);
    final publicationId = _publicationId;
    final cover = _coverAsset;
    final gallery = _galleryAssets;
    final attachments = _attachmentAssets;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.perm_media_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Contenido multimedia',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isLoadingAssets || _isManagingAssets)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              publicationId == null
                  ? 'Guarda primero el comunicado como borrador para '
                      'habilitar la carga segura de archivos.'
                  : 'Agrega una portada, imágenes complementarias o '
                      'documentos institucionales.',
              style: theme.textTheme.bodyMedium,
            ),
            if (_assetError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _assetError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed:
                  !_canManageAssets || _isManagingAssets ? null : _selectCover,
              icon: Icon(
                cover == null
                    ? Icons.add_photo_alternate_outlined
                    : Icons.change_circle_outlined,
              ),
              label: Text(
                cover == null ? 'Agregar portada' : 'Cambiar portada',
              ),
            ),
            if (cover != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildAssetTile(context, cover),
            ],
            const Divider(height: AppSpacing.xlg),
            OutlinedButton.icon(
              onPressed:
                  !_canManageAssets || _isManagingAssets
                      ? null
                      : _selectGalleryImages,
              icon: const Icon(Icons.collections_outlined),
              label: const Text('Agregar imágenes'),
            ),
            if (gallery.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Galería (${gallery.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...gallery.map((asset) => _buildAssetTile(context, asset)),
            ],
            const Divider(height: AppSpacing.xlg),
            OutlinedButton.icon(
              onPressed:
                  !_canManageAssets || _isManagingAssets
                      ? null
                      : _selectAttachments,
              icon: const Icon(Icons.attach_file_outlined),
              label: const Text('Adjuntar documentos'),
            ),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Documentos (${attachments.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...attachments.map((asset) => _buildAssetTile(context, asset)),
            ],
            if (publicationId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Máximo 25 MiB por archivo.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssetTile(BuildContext context, PublicationAsset asset) {
    final theme = Theme.of(context);

    final documentIcon =
        asset.isPdf
            ? Icons.picture_as_pdf_outlined
            : Icons.description_outlined;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          asset.type.isImage
              ? SizedBox(
                width: 64,
                height: 48,
                child: PublicationAssetImage(
                  asset: asset,
                  width: 64,
                  height: 48,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                ),
              )
              : SizedBox(
                width: 64,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(documentIcon),
                ),
              ),
      title: Text(
        asset.originalName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${asset.extension.toUpperCase()} · '
        '${_formatFileSize(asset.sizeBytes)}',
      ),
      trailing: IconButton(
        tooltip: 'Eliminar archivo',
        onPressed: _isManagingAssets ? null : () => _removeAsset(asset),
        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kilobytes = bytes / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  Widget _buildAudienceSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audiencia',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Los criterios de distintas categorías se combinan. '
              'Por ejemplo: estudiantes de ITIC de noveno semestre.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Todos los usuarios activos'),
              subtitle: const Text(
                'El comunicado será visible para toda la comunidad.',
              ),
              value: _allUsers,
              onChanged:
                  _isSubmitting
                      ? null
                      : (value) {
                        _setFormState(() {
                          _allUsers = value;

                          if (value) {
                            _specificRecipients = false;
                            _selectedRoles.clear();
                            _selectedCareerIds.clear();
                            _selectedSemesters.clear();
                            _allSemesters = true;
                            _groupsController.clear();
                            _selectedRecipients.clear();
                            _recipientSearchResults = const [];
                            _recipientSearchController.clear();
                            _recipientSearchError = null;
                          }
                        });
                      },
            ),
            if (!_allUsers) ...[
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Personas específicas'),
                subtitle: const Text(
                  'Busca y selecciona destinatarios por matrícula, '
                  'correo institucional o nombre.',
                ),
                value: _specificRecipients,
                onChanged:
                    _isSubmitting
                        ? null
                        : (value) {
                          _setFormState(() {
                            _specificRecipients = value;

                            if (value) {
                              _selectedRoles.clear();
                              _selectedCareerIds.clear();
                              _selectedSemesters.clear();
                              _allSemesters = true;
                              _groupsController.clear();
                            } else {
                              _selectedRecipients.clear();
                              _recipientSearchResults = const [];
                              _recipientSearchController.clear();
                              _recipientSearchError = null;
                            }
                          });
                        },
              ),
              const Divider(),
              if (!_specificRecipients) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Roles',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: AppUserRole.values
                      .map(
                        (role) => FilterChip(
                          label: Text(_roleLabel(role)),
                          selected: _selectedRoles.contains(role),
                          onSelected:
                              _isSubmitting
                                  ? null
                                  : (selected) {
                                    _setFormState(() {
                                      if (selected) {
                                        _selectedRoles.add(role);
                                      } else {
                                        _selectedRoles.remove(role);
                                      }
                                    });
                                  },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Carreras',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...InstitutionalCareers.values.map(
                  (career) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(career.name),
                    subtitle: Text(career.id),
                    value: _selectedCareerIds.contains(career.id),
                    onChanged:
                        _isSubmitting
                            ? null
                            : (selected) {
                              _setFormState(() {
                                if (selected ?? false) {
                                  _selectedCareerIds.add(career.id);
                                } else {
                                  _selectedCareerIds.remove(career.id);
                                }
                              });
                            },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Semestres',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Todos los semestres'),
                  subtitle: const Text(
                    'No se aplicará un filtro por semestre.',
                  ),
                  value: _allSemesters,
                  onChanged:
                      _isSubmitting
                          ? null
                          : (selected) {
                            _setFormState(() {
                              _allSemesters = selected ?? true;

                              if (_allSemesters) {
                                _selectedSemesters.clear();
                              }
                            });
                          },
                ),
                if (!_allSemesters)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: List<int>.generate(14, (index) => index + 1)
                        .map(
                          (semester) => FilterChip(
                            label: Text('$semester.º'),
                            selected: _selectedSemesters.contains(semester),
                            onSelected:
                                _isSubmitting
                                    ? null
                                    : (selected) {
                                      _setFormState(() {
                                        if (selected) {
                                          _selectedSemesters.add(semester);
                                        } else {
                                          _selectedSemesters.remove(semester);
                                        }
                                      });
                                    },
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _groupsController,
                  enabled: !_isSubmitting,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Grupos',
                    hintText: 'Ej. T51, T52, T91',
                    helperText: 'Separa varios grupos con comas.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_specificRecipients) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildDirectRecipientsSection(context),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                _audienceSummary(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDirectRecipientsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estudiantes específicos',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Busca por matrícula, correo institucional o nombre. '
          'Los estudiantes seleccionados se incluirán aunque pertenezcan '
          'a carreras, semestres o grupos distintos.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _recipientSearchController,
          enabled: !_isSubmitting && !_isSearchingRecipients,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Buscar estudiante',
            hintText: 'Ej. L191200038 o correo institucional',
            border: const OutlineInputBorder(),
            suffixIcon:
                _isSearchingRecipients
                    ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : IconButton(
                      tooltip: 'Buscar',
                      onPressed: _isSubmitting ? null : _searchRecipients,
                      icon: const Icon(Icons.search),
                    ),
          ),
          onSubmitted: _isSubmitting ? null : (_) => _searchRecipients(),
        ),
        if (_recipientSearchError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _recipientSearchError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (_recipientSearchResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Resultados', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          ..._recipientSearchResults.map((recipient) {
            final selected = _selectedRecipients.containsKey(recipient.uid);

            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(_recipientInitials(recipient)),
                ),
                title: Text(
                  recipient.displayName?.trim().isNotEmpty ?? false
                      ? recipient.displayName!
                      : 'Estudiante sin nombre',
                ),
                subtitle: Text(_recipientDescription(recipient)),
                trailing: IconButton(
                  tooltip:
                      selected ? 'Quitar destinatario' : 'Agregar destinatario',
                  onPressed:
                      _isSubmitting ? null : () => _toggleRecipient(recipient),
                  icon: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                  ),
                ),
              ),
            );
          }),
        ],
        if (_selectedRecipients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Destinatarios seleccionados '
            '(${_selectedRecipients.length})',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          ..._selectedRecipients.values.map(
            (recipient) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(
                recipient.displayName?.trim().isNotEmpty ?? false
                    ? recipient.displayName!
                    : recipient.controlNumber ??
                        recipient.email ??
                        'Usuario seleccionado',
              ),
              subtitle: Text(_recipientDescription(recipient)),
              trailing: IconButton(
                tooltip: 'Quitar',
                onPressed:
                    _isSubmitting ? null : () => _toggleRecipient(recipient),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _searchRecipients() async {
    final query = _recipientSearchController.text.trim();

    if (query.length < 2) {
      setState(() {
        _recipientSearchResults = const [];
        _recipientSearchError = 'Escribe al menos 2 caracteres para buscar.';
      });
      return;
    }

    setState(() {
      _isSearchingRecipients = true;
      _recipientSearchError = null;
    });

    try {
      final results = await context
          .read<AnnouncementRepository>()
          .searchRecipients(query: query);

      if (!mounted) {
        return;
      }

      setState(() {
        _recipientSearchResults = results;
        _recipientSearchError =
            results.isEmpty ? 'No se encontraron perfiles activos.' : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _recipientSearchResults = const [];
        _recipientSearchError = 'No se pudo realizar la búsqueda: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isSearchingRecipients = false);
      }
    }
  }

  void _toggleRecipient(AnnouncementRecipient recipient) {
    _setFormState(() {
      if (_selectedRecipients.containsKey(recipient.uid)) {
        _selectedRecipients.remove(recipient.uid);
      } else {
        _selectedRecipients[recipient.uid] = recipient;
      }
    });
  }

  String _recipientDescription(AnnouncementRecipient recipient) {
    final parts = <String>[];

    final controlNumber = recipient.controlNumber?.trim();
    if (controlNumber != null && controlNumber.isNotEmpty) {
      parts.add(controlNumber);
    }

    final email = recipient.email?.trim();
    if (email != null && email.isNotEmpty) {
      parts.add(email);
    }

    if (recipient.careerId != null) {
      parts.add(InstitutionalCareers.labelFor(recipient.careerId!));
    }

    if (recipient.semester != null) {
      parts.add('${recipient.semester}.º semestre');
    }

    if (recipient.groupId != null) {
      parts.add(recipient.groupId!.toUpperCase());
    }

    return parts.isEmpty ? _roleLabel(recipient.role) : parts.join(' · ');
  }

  String _recipientInitials(AnnouncementRecipient recipient) {
    final name = recipient.displayName?.trim();

    if (name != null && name.isNotEmpty) {
      final words = name
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .take(2)
          .toList(growable: false);

      return words.map((word) => word.substring(0, 1).toUpperCase()).join();
    }

    final controlNumber = recipient.controlNumber?.trim();

    if (controlNumber != null && controlNumber.isNotEmpty) {
      return controlNumber.substring(0, 1).toUpperCase();
    }

    return '?';
  }

  AnnouncementTarget _buildTarget() {
    if (_allUsers) {
      return const AnnouncementTarget.all();
    }

    if (_specificRecipients) {
      return AnnouncementTarget(
        userUids: Set<String>.unmodifiable(_selectedRecipients.keys),
      );
    }

    return AnnouncementTarget(
      roles: Set<AppUserRole>.unmodifiable(_selectedRoles),
      careerIds: Set<String>.unmodifiable(_selectedCareerIds),
      semesters:
          _allSemesters
              ? const <int>{}
              : Set<int>.unmodifiable(_selectedSemesters),
      groupIds: Set<String>.unmodifiable(_parsedGroups()),
    );
  }

  Set<String> _parsedGroups() {
    return _groupsController.text
        .split(',')
        .map((group) => group.trim().toLowerCase())
        .where((group) => group.isNotEmpty)
        .toSet();
  }

  String _audienceSummary() {
    if (_allUsers) {
      return 'El comunicado se enviará a toda la comunidad activa.';
    }

    if (_specificRecipients) {
      final count = _selectedRecipients.length;

      if (count == 0) {
        return 'Todavía no hay personas seleccionadas.';
      }

      return count == 1
          ? 'El comunicado se enviará a 1 persona específica.'
          : 'El comunicado se enviará a $count personas específicas.';
    }

    final parts = <String>[];

    if (_selectedRoles.isNotEmpty) {
      parts.add('${_selectedRoles.length} rol(es)');
    }

    if (_selectedCareerIds.isNotEmpty) {
      parts.add('${_selectedCareerIds.length} carrera(s)');
    }

    if (_allSemesters && _selectedCareerIds.isNotEmpty) {
      parts.add('todos los semestres');
    } else if (_selectedSemesters.isNotEmpty) {
      parts.add('${_selectedSemesters.length} semestre(s)');
    }

    final groups = _parsedGroups();

    if (groups.isNotEmpty) {
      parts.add('${groups.length} grupo(s)');
    }

    if (parts.isEmpty) {
      return 'Todavía no hay criterios seleccionados.';
    }

    return 'Audiencia configurada: ${parts.join(', ')}.';
  }

  static String _roleLabel(AppUserRole role) {
    return switch (role) {
      AppUserRole.student => 'Estudiantes',
      AppUserRole.teacher => 'Docentes',
      AppUserRole.admin => 'Administradores',
      AppUserRole.superAdmin => 'Superadministradores',
    };
  }

  static String _priorityLabel(AnnouncementPriority priority) {
    return switch (priority) {
      AnnouncementPriority.low => 'Baja',
      AnnouncementPriority.normal => 'Normal',
      AnnouncementPriority.high => 'Importante',
      AnnouncementPriority.urgent => 'Urgente',
    };
  }
}
