import 'package:conecta_itt/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProblemReportsPage extends StatefulWidget {
  const AdminProblemReportsPage({super.key});

  @override
  State<AdminProblemReportsPage> createState() =>
      _AdminProblemReportsPageState();
}

class _AdminProblemReportsPageState extends State<AdminProblemReportsPage> {
  String _filter = 'pending';
  late Future<List<Map<String, dynamic>>> _reports;

  static const _statuses = <String, String>{
    'pending': 'Pendiente',
    'in_review': 'En revisión',
    'resolved': 'Resuelto',
  };

  static const _categories = <String, String>{
    'app_error': 'Error de la aplicación',
    'account': 'Acceso o cuenta',
    'notifications': 'Comunicados y notificaciones',
    'academic': 'Horario y actividades académicas',
    'other': 'Otro problema',
  };

  @override
  void initState() {
    super.initState();
    _reports = _fetchReports();
  }

  Future<List<Map<String, dynamic>>> _fetchReports() async {
    final client = Supabase.instance.client;
    final query = client
        .from('problem_reports')
        .select(
          'id, reporter_id, category, description, '
          'steps_to_reproduce, status, admin_response, '
          'created_at, handled_by, handled_at',
        );

    final data =
        _filter == 'all'
            ? await query.order('created_at', ascending: false).limit(200)
            : await query
                .eq('status', _filter)
                .order('created_at', ascending: false)
                .limit(200);

    return List<Map<String, dynamic>>.from(data);
  }

  void _refresh() {
    setState(() => _reports = _fetchReports());
  }

  Future<void> _review(Map<String, dynamic> report) async {
    final responseController = TextEditingController(
      text: (report['admin_response'] as String?) ?? '',
    );
    var status = (report['status'] as String?) ?? 'pending';
    var saving = false;

    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, updateDialog) {
              return AlertDialog(
                title: const Text('Atender reporte'),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['description']?.toString() ?? '',
                          style: Theme.of(dialogContext).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              _statuses.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              saving
                                  ? null
                                  : (value) {
                                    if (value != null) {
                                      updateDialog(() => status = value);
                                    }
                                  },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: responseController,
                          enabled: !saving,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Respuesta administrativa',
                            hintText: 'Escribe el seguimiento del reporte...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed:
                        saving
                            ? null
                            : () async {
                              updateDialog(() => saving = true);
                              try {
                                await Supabase.instance.client.rpc(
                                  'review_problem_report',
                                  params: {
                                    'p_report_id': report['id'],
                                    'p_status': status,
                                    'p_admin_response':
                                        responseController.text.trim(),
                                  },
                                );
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop(true);
                                }
                              } catch (_) {
                                if (dialogContext.mounted) {
                                  updateDialog(() => saving = false);
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No fue posible guardar la respuesta.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                    child: Text(saving ? 'Guardando...' : 'Guardar cambios'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved == true && mounted) {
        _refresh();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reporte actualizado.')));
      }
    } finally {
      responseController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorized =
        context
            .watch<AppBloc>()
            .state
            .institutionalProfile
            ?.canAccessAdministration ??
        false;

    if (!authorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportes de problemas')),
        body: const Center(child: Text('No tienes acceso a esta sección.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de problemas'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Actualizar reportes',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _filter,
              decoration: const InputDecoration(
                labelText: 'Filtrar por estado',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('Todos los estados'),
                ),
                ..._statuses.entries.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filter = value;
                    _reports = _fetchReports();
                  });
                }
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _reports,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No se pudieron cargar los reportes.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _refresh,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                final reports =
                    (snapshot.data ?? [])
                        .where(
                          (report) =>
                              _filter == 'all' || report['status'] == _filter,
                        )
                        .toList();

                if (reports.isEmpty) {
                  return const Center(
                    child: Text('No hay reportes en esta categoría.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await _reports;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      final category =
                          report['category']?.toString() ?? 'other';
                      final status = report['status']?.toString() ?? 'pending';
                      final steps = report['steps_to_reproduce']?.toString();

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _categories[category] ?? 'Otro problema',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _statuses[status] ?? status,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(report['description']?.toString() ?? ''),
                              if (steps != null && steps.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Pasos para reproducirlo:',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(steps),
                              ],
                              if (report['admin_response'] != null &&
                                  report['admin_response']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Respuesta:',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(report['admin_response'].toString()),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _review(report),
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text('Atender'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
