import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only administrative view of academic group offerings.
///
/// Mutations are intentionally excluded from this initial screen.
class AdminAcademicGroupOfferingsPage extends StatefulWidget {
  const AdminAcademicGroupOfferingsPage({super.key});

  @override
  State<AdminAcademicGroupOfferingsPage> createState() =>
      _AdminAcademicGroupOfferingsPageState();
}

class _AdminAcademicGroupOfferingsPageState
    extends State<AdminAcademicGroupOfferingsPage> {
  static const _periods = <String>['2026-2', '2027-1'];

  late final AdminAcademicOfferingsRepository _repository;

  String _periodCode = '2026-2';
  String _careerId = '';
  int _semester = 0;

  late Future<List<AdminAcademicGroupOffering>> _offerings;

  String? _busyGroupId;
  bool _creatingGroup = false;

  @override
  void initState() {
    super.initState();

    _repository = AdminAcademicOfferingsRepository(
      supabaseClient: Supabase.instance.client,
    );

    _offerings = _fetch();
  }

  Future<List<AdminAcademicGroupOffering>> _fetch() {
    return _repository.fetchOfferings(
      periodCode: _periodCode,
      careerId: _careerId.isEmpty ? null : _careerId,
      semester: _semester == 0 ? null : _semester,
    );
  }

  void _reload() {
    setState(() {
      _offerings = _fetch();
    });
  }

  Future<void> _changeGroupStatus(AdminAcademicGroupOffering offering) async {
    if (_busyGroupId != null) return;

    final activating = !offering.groupActive;
    final action = activating ? 'activar' : 'desactivar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(activating ? 'Activar grupo' : 'Desactivar grupo'),
            content: Text(
              '¿Deseas $action el grupo '
              '${offering.groupName} (${offering.groupId})?'
              '\n\n'
              'Esta operación quedará registrada '
              'en la auditoría administrativa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(activating ? 'Activar' : 'Desactivar'),
              ),
            ],
          ),
    );

    if (!mounted || confirmed != true || _busyGroupId != null) {
      return;
    }

    // La comprobacion visual no sustituye a PostgreSQL.
    // Se vuelve a comprobar la sesion antes de escribir.
    final appState = context.read<AppBloc>().state;
    final profile = appState.institutionalProfile;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (profile == null ||
        !profile.canManageStudentAcademics ||
        userId == null ||
        userId != appState.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La sesión no tiene permisos administrativos vigentes.',
          ),
        ),
      );
      return;
    }

    setState(() => _busyGroupId = offering.groupId);

    try {
      await _repository.setGroupActive(
        groupId: offering.groupId,
        active: activating,
      );

      if (!mounted) return;

      _reload();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activating
                ? 'Grupo ${offering.groupId} activado.'
                : 'Grupo ${offering.groupId} desactivado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo cambiar el estado del grupo. '
            'Comprueba sus ofertas, tus permisos y la conexión.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyGroupId = null);
      }
    }
  }

  Future<void> _changeOfferingStatus(
    AdminAcademicGroupOffering offering,
  ) async {
    if (_busyGroupId != null) return;

    final enabling = !offering.isEnabled;

    final actionQuestion =
        enabling
            ? '¿Deseas habilitar esta oferta académica?'
            : '¿Deseas retirar esta oferta académica?';

    if (enabling && !offering.groupActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debes activar el grupo académico.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(enabling ? 'Habilitar oferta' : 'Retirar oferta'),
            content: Text(
              'Grupo: ${offering.groupId}\n'
              'Periodo académico: ${offering.periodCode}\n\n'
              '$actionQuestion\n\n'
              'Esta operación quedará registrada '
              'en la auditoría administrativa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(enabling ? 'Habilitar' : 'Retirar'),
              ),
            ],
          ),
    );

    if (!mounted || confirmed != true || _busyGroupId != null) {
      return;
    }

    final appState = context.read<AppBloc>().state;
    final profile = appState.institutionalProfile;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (profile == null ||
        !profile.canManageStudentAcademics ||
        userId == null ||
        userId != appState.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La sesión no tiene permisos administrativos vigentes.',
          ),
        ),
      );
      return;
    }

    setState(() => _busyGroupId = offering.groupId);

    try {
      await _repository.setGroupOffering(
        periodCode: offering.periodCode,
        groupId: offering.groupId,
        isOffered: enabling,
      );

      if (!mounted) return;

      _reload();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabling
                ? 'Oferta ${offering.groupId} habilitada '
                    'para ${offering.periodCode}.'
                : 'Oferta ${offering.groupId} retirada '
                    'de ${offering.periodCode}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo modificar la oferta. '
            'Comprueba el periodo, el estado del grupo, '
            'los permisos y la conexión.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyGroupId = null);
      }
    }
  }

  Future<void> _createAcademicGroup() async {
    if (_creatingGroup || _busyGroupId != null) return;

    String selectedCareer =
        _careerId.isNotEmpty ? _careerId : InstitutionalCareers.values.first.id;
    int selectedSemester = _semester > 0 ? _semester : 1;
    int selectedParallel = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, updateDialog) => AlertDialog(
                  title: const Text('Crear grupo académico'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Selecciona la carrera, el semestre y el paralelo. '
                          'El identificador se generará automáticamente.',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCareer,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Carrera',
                            border: OutlineInputBorder(),
                          ),
                          items: InstitutionalCareers.values
                              .map(
                                (career) => DropdownMenuItem(
                                  value: career.id,
                                  child: Text(
                                    career.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              updateDialog(() => selectedCareer = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: selectedSemester,
                          decoration: const InputDecoration(
                            labelText: 'Semestre ordinario',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            9,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}.º semestre'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              updateDialog(() => selectedSemester = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: selectedParallel,
                          decoration: const InputDecoration(
                            labelText: 'Número de paralelo',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(
                            9,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('Paralelo ${index + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              updateDialog(() => selectedParallel = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'El grupo se registrará inactivo y sin oferta. '
                          'Si ya existe con los mismos datos, '
                          'se conservará el registro existente.',
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
          ),
    );

    if (!mounted ||
        confirmed != true ||
        _creatingGroup ||
        _busyGroupId != null) {
      return;
    }

    final appState = context.read<AppBloc>().state;
    final profile = appState.institutionalProfile;
    final authenticatedId = Supabase.instance.client.auth.currentUser?.id;

    if (profile == null ||
        !profile.canManageStudentAcademics ||
        authenticatedId == null ||
        authenticatedId != appState.user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos administrativos vigentes.'),
        ),
      );
      return;
    }

    final finalConfirmation = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirmar registro'),
            content: Text(
              'Carrera: ${InstitutionalCareers.labelFor(selectedCareer)}\n'
              'Semestre: $selectedSemester\n'
              'Paralelo: $selectedParallel\n\n'
              '¿Deseas registrar este grupo académico?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Registrar'),
              ),
            ],
          ),
    );

    if (!mounted ||
        finalConfirmation != true ||
        _creatingGroup ||
        _busyGroupId != null) {
      return;
    }

    setState(() => _creatingGroup = true);

    try {
      final groupId = await _repository.createGroup(
        careerId: selectedCareer,
        semester: selectedSemester,
        parallel: selectedParallel,
      );

      if (!mounted) return;

      setState(() {
        _careerId = selectedCareer;
        _semester = selectedSemester;
        _offerings = _fetch();
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Grupo académico disponible'),
              content: Text(
                'El grupo $groupId está disponible en el '
                'catálogo académico.\n\n'
                'Si ya existía con los mismos datos, '
                'se conservó su registro original.\n\n'
                'Para admitir estudiantes, primero debes '
                'activar el grupo y habilitar su oferta '
                'en el periodo correspondiente.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible registrar el grupo. '
            'Comprueba los permisos y los datos académicos.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingGroup = false);
      }
    }
  }

  Future<void> _refresh() async {
    final future = _fetch();

    setState(() {
      _offerings = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the corresponding error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppBloc>().state;
    final profile = appState.institutionalProfile;
    final authenticatedId = Supabase.instance.client.auth.currentUser?.id;

    final authorized =
        profile != null &&
        profile.canManageStudentAcademics &&
        authenticatedId != null &&
        authenticatedId == appState.user.id;

    if (!authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grupos y ofertas')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tienes permisos para consultar ofertas '
              'académicas administrativas.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos y ofertas'),
        actions: [
          IconButton(
            onPressed:
                _creatingGroup || _busyGroupId != null
                    ? null
                    : _createAcademicGroup,
            tooltip: 'Crear grupo académico',
            icon:
                _creatingGroup
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.group_add_outlined),
          ),
          IconButton(
            onPressed: _reload,
            tooltip: 'Actualizar ofertas',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: FutureBuilder<List<AdminAcademicGroupOffering>>(
                future: _offerings,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildMessage(
                      icon: Icons.cloud_off_outlined,
                      message:
                          'No fue posible consultar las ofertas. '
                          'Comprueba la conexión y los permisos.',
                      action: TextButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    );
                  }

                  final offerings =
                      snapshot.data ?? const <AdminAcademicGroupOffering>[];

                  if (offerings.isEmpty) {
                    return _buildMessage(
                      icon: Icons.groups_outlined,
                      message:
                          'No existen grupos para los filtros seleccionados.',
                      action: TextButton(
                        onPressed: () {
                          setState(() {
                            _careerId = '';
                            _semester = 0;
                            _offerings = _fetch();
                          });
                        },
                        child: const Text('Limpiar filtros'),
                      ),
                    );
                  }

                  return RefreshIndicator.adaptive(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: offerings.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${offerings.length} ${offerings.length == 1 ? 'grupo encontrado' : 'grupos encontrados'}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          );
                        }

                        return _buildGroupCard(offerings[index - 1]);
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consulta administrativa por periodo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Administra grupos académicos y sus ofertas por periodo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('period-$_periodCode'),
            initialValue: _periodCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Periodo académico',
              border: OutlineInputBorder(),
            ),
            items: _periods
                .map(
                  (period) =>
                      DropdownMenuItem(value: period, child: Text(period)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _periodCode = value;
                _offerings = _fetch();
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('career-$_careerId'),
            initialValue: _careerId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Carrera',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Todas las carreras'),
              ),
              ...InstitutionalCareers.values.map(
                (career) => DropdownMenuItem(
                  value: career.id,
                  child: Text(career.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _careerId = value;
                _offerings = _fetch();
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey('semester-$_semester'),
            initialValue: _semester,
            decoration: const InputDecoration(
              labelText: 'Semestre',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: 0,
                child: Text('Todos los semestres'),
              ),
              ...List.generate(
                9,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}.º semestre'),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _semester = value;
                _offerings = _fetch();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(AdminAcademicGroupOffering offering) {
    final label =
        offering.isEnabled
            ? 'Ofertado'
            : offering.isDisabled
            ? 'Desactivado'
            : 'Sin configurar';

    final icon =
        offering.isEnabled
            ? Icons.check_circle_outline
            : offering.isDisabled
            ? Icons.remove_circle_outline
            : Icons.pending_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offering.groupName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(avatar: Icon(icon, size: 18), label: Text(label)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              offering.careerId == null
                  ? 'Carrera no asignada'
                  : InstitutionalCareers.labelFor(offering.careerId!),
            ),
            const SizedBox(height: 4),
            Text(
              offering.semester == null
                  ? 'Semestre no asignado'
                  : '${offering.semester}.º semestre',
            ),
            const SizedBox(height: 4),
            Text(
              offering.groupActive
                  ? 'Grupo activo en el catálogo'
                  : 'Grupo inactivo en el catálogo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _busyGroupId != null
                        ? null
                        : () => _changeGroupStatus(offering),
                icon:
                    _busyGroupId == offering.groupId
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          offering.groupActive
                              ? Icons.power_settings_new_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                label: Text(
                  _busyGroupId == offering.groupId
                      ? 'Procesando...'
                      : offering.groupActive
                      ? 'Desactivar grupo'
                      : 'Activar grupo',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Oferta académica · ${offering.periodCode}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (!offering.groupActive && !offering.isEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Activa primero el grupo para habilitar su oferta.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _busyGroupId != null ||
                            (!offering.groupActive && !offering.isEnabled)
                        ? null
                        : () => _changeOfferingStatus(offering),
                icon:
                    _busyGroupId == offering.groupId
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          offering.isEnabled
                              ? Icons.remove_circle_outline_rounded
                              : Icons.add_circle_outline_rounded,
                        ),
                label: Text(
                  _busyGroupId == offering.groupId
                      ? 'Procesando...'
                      : offering.isEnabled
                      ? 'Retirar oferta'
                      : 'Habilitar oferta',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    required Widget action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            action,
          ],
        ),
      ),
    );
  }
}
