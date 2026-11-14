import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();

  String _category = 'app_error';
  bool _submitting = false;

  static const _categories = <String, String>{
    'app_error': 'Error de la aplicación',
    'account': 'Acceso o cuenta',
    'notifications': 'Comunicados o notificaciones',
    'academic': 'Horario o actividades académicas',
    'other': 'Otro problema',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar un reporte.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await client.from('problem_reports').insert({
        'category': _category,
        'description': _descriptionController.text.trim(),
        'steps_to_reproduce':
            _stepsController.text.trim().isEmpty
                ? null
                : _stepsController.text.trim(),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Reporte enviado'),
              content: const Text(
                'Recibimos tu reporte correctamente. '
                'Gracias por ayudarnos a mejorar Conecta ITT.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible enviar el reporte. '
            'Comprueba tu conexión e inténtalo nuevamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar un problema')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                Icons.bug_report_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '¿Encontraste algún problema?',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuéntanos qué ocurrió para que podamos revisarlo. '
                'No incluyas contraseñas ni códigos de acceso.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items:
                    _categories.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                onChanged:
                    _submitting
                        ? null
                        : (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Describe el problema',
                  hintText: 'Explica qué sucedió...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 20) {
                    return 'Escribe al menos 20 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stepsController,
                maxLines: 4,
                maxLength: 1500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Cómo ocurrió? (opcional)',
                  hintText: 'Describe los pasos para reproducirlo...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon:
                    _submitting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_outlined),
                label: Text(_submitting ? 'Enviando...' : 'Enviar reporte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
