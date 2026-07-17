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

  AnnouncementPriority _priority = AnnouncementPriority.normal;
  bool _allUsers = true;
  final Set<AppUserRole> _selectedRoles = {};
  final Set<String> _selectedCareerIds = {};
  final Set<int> _selectedSemesters = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _groupsController.dispose();
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

  AnnouncementTarget _buildTarget() {
    if (_allUsers) {
      return const AnnouncementTarget.all();
    }

    return AnnouncementTarget(
      roles: Set<AppUserRole>.unmodifiable(_selectedRoles),
      careerIds: Set<String>.unmodifiable(_selectedCareerIds),
      semesters: Set<int>.unmodifiable(_selectedSemesters),
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
