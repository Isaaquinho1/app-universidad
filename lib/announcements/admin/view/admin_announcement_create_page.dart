import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rtu_mirea_app/announcements/announcements.dart';
import 'package:rtu_mirea_app/app/app.dart';
import 'package:rtu_mirea_app/institutional_profile/institutional_profile.dart';

class AdminAnnouncementCreatePage extends StatefulWidget {
  const AdminAnnouncementCreatePage({super.key});

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
  final Set<AppUserRole> _selectedRoles = {};
  final Set<String> _selectedCareerIds = {};
  final Set<int> _selectedSemesters = {};
  final Map<String, AnnouncementRecipient> _selectedRecipients = {};
  List<AnnouncementRecipient> _recipientSearchResults = const [];
  bool _isSearchingRecipients = false;
  String? _recipientSearchError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _groupsController.dispose();
    _recipientSearchController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool publish}) async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
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

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now().toUtc();
      final authorName = profile.displayName?.trim();

      final announcement = Announcement(
        id: '',
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        summary:
            _summaryController.text.trim().isEmpty
                ? null
                : _summaryController.text.trim(),
        authorUid: profile.uid,
        authorName:
            authorName == null || authorName.isEmpty
                ? 'Administración Conecta ITT'
                : authorName,
        target: target,
        status:
            publish ? AnnouncementStatus.published : AnnouncementStatus.draft,
        priority: _priority,
        createdAt: now,
        updatedAt: now,
        publishedAt: publish ? now : null,
      );

      await context.read<AnnouncementRepository>().createAnnouncement(
        announcement,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        publish
            ? 'Comunicado publicado correctamente.'
            : 'Comunicado guardado como borrador.',
      );

      Navigator.of(context).pop(true);
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
        appBar: AppBar(title: const Text('Crear comunicado')),
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
      appBar: AppBar(title: const Text('Crear comunicado')),
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
                            setState(() => _priority = priority);
                          }
                        },
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAudienceSection(context),
              const SizedBox(height: AppSpacing.xlg),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _submit(publish: false),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar borrador'),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : () => _submit(publish: true),
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
          ),
        ),
      ),
    );
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
                        setState(() {
                          _allUsers = value;

                          if (value) {
                            _selectedRoles.clear();
                            _selectedCareerIds.clear();
                            _selectedSemesters.clear();
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
                                  setState(() {
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
                            setState(() {
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
                                  setState(() {
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
              const SizedBox(height: AppSpacing.lg),
              _buildDirectRecipientsSection(context),
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
    setState(() {
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

    return AnnouncementTarget(
      roles: Set<AppUserRole>.unmodifiable(_selectedRoles),
      careerIds: Set<String>.unmodifiable(_selectedCareerIds),
      semesters: Set<int>.unmodifiable(_selectedSemesters),
      groupIds: Set<String>.unmodifiable(_parsedGroups()),
      userUids: Set<String>.unmodifiable(_selectedRecipients.keys),
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
    final parts = <String>[];

    if (_selectedRoles.isNotEmpty) {
      parts.add('${_selectedRoles.length} rol(es)');
    }

    if (_selectedCareerIds.isNotEmpty) {
      parts.add('${_selectedCareerIds.length} carrera(s)');
    }

    if (_selectedSemesters.isNotEmpty) {
      parts.add('${_selectedSemesters.length} semestre(s)');
    }

    final groups = _parsedGroups();

    if (groups.isNotEmpty) {
      parts.add('${groups.length} grupo(s)');
    }

    if (_selectedRecipients.isNotEmpty) {
      parts.add('${_selectedRecipients.length} destinatario(s) directo(s)');
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
