import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:flutter/material.dart';

class TaskCategoryFormData {
  const TaskCategoryFormData({required this.name, required this.colorValue});

  final String name;
  final int colorValue;
}

class TaskCategoryFormSheet extends StatefulWidget {
  const TaskCategoryFormSheet({super.key, this.category});

  final TaskCategory? category;

  @override
  State<TaskCategoryFormSheet> createState() => _TaskCategoryFormSheetState();
}

class _TaskCategoryFormSheetState extends State<TaskCategoryFormSheet> {
  static const _availableColors = <int>[
    0xFF1565C0,
    0xFF6A1B9A,
    0xFFC62828,
    0xFFEF6C00,
    0xFF2E7D32,
    0xFF00695C,
    0xFF00838F,
    0xFFAD1457,
    0xFF4527A0,
    0xFF455A64,
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late int _selectedColor;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.category?.name ?? '');

    _selectedColor = widget.category?.colorValue ?? _availableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      TaskCategoryFormData(
        name: _nameController.text.trim(),
        colorValue: _selectedColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + keyboardInset,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.deactive.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _isEditing ? 'Editar categoría' : 'Nueva categoría',
                  style: AppTextStyle.h4.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Personaliza cómo clasificas tus actividades.',
                  style: AppTextStyle.body.copyWith(color: colors.deactive),
                ),
                const SizedBox(height: AppSpacing.xlg),
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej. Laboratorio',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (value) {
                    final normalized = value?.trim() ?? '';

                    if (normalized.isEmpty) {
                      return 'Escribe el nombre de la categoría.';
                    }

                    if (normalized.length < 2) {
                      return 'El nombre es demasiado corto.';
                    }

                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Color', style: AppTextStyle.bodyBold),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final colorValue in _availableColors)
                      _CategoryColorOption(
                        colorValue: colorValue,
                        selected: colorValue == _selectedColor,
                        onTap: () {
                          setState(() {
                            _selectedColor = colorValue;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xlg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      _isEditing ? Icons.save_rounded : Icons.add_rounded,
                    ),
                    label: Text(
                      _isEditing ? 'Guardar cambios' : 'Agregar categoría',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryColorOption extends StatelessWidget {
  const _CategoryColorOption({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Color seleccionado' : 'Seleccionar color',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
              width: 3,
            ),
          ),
          child:
              selected
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : null,
        ),
      ),
    );
  }
}
