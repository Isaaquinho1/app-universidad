import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:flutter/material.dart';

class AcademicSubjectFormData {
  const AcademicSubjectFormData({
    required this.name,
    required this.colorValue,
    this.code,
    this.teacherName,
    this.notes,
  });

  final String name;
  final String? code;
  final String? teacherName;
  final int colorValue;
  final String? notes;
}

class AcademicSubjectFormSheet extends StatefulWidget {
  const AcademicSubjectFormSheet({super.key, this.subject});

  final AcademicSubject? subject;

  @override
  State<AcademicSubjectFormSheet> createState() =>
      _AcademicSubjectFormSheetState();
}

class _AcademicSubjectFormSheetState extends State<AcademicSubjectFormSheet> {
  static const _availableColors = <int>[
    0xFF075578,
    0xFF1565C0,
    0xFF283593,
    0xFF6A1B9A,
    0xFFAD1457,
    0xFFC62828,
    0xFFEF6C00,
    0xFF2E7D32,
    0xFF00695C,
    0xFF455A64,
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _teacherController;
  late final TextEditingController _notesController;

  late int _selectedColor;

  bool get _isEditing => widget.subject != null;

  @override
  void initState() {
    super.initState();

    final subject = widget.subject;

    _nameController = TextEditingController(text: subject?.name ?? '');
    _codeController = TextEditingController(text: subject?.code ?? '');
    _teacherController = TextEditingController(
      text: subject?.teacherName ?? '',
    );
    _notesController = TextEditingController(text: subject?.notes ?? '');

    _selectedColor = subject?.colorValue ?? _availableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _teacherController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _normalizeOptional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      AcademicSubjectFormData(
        name: _nameController.text.trim(),
        code: _normalizeOptional(_codeController.text),
        teacherName: _normalizeOptional(_teacherController.text),
        colorValue: _selectedColor,
        notes: _normalizeOptional(_notesController.text),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Theme.of(
            context,
          ).extension<AppColors>()!.deactive.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      color: Theme.of(context)
                          .extension<AppColors>()!
                          .deactive
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _isEditing ? 'Editar materia' : 'Nueva materia',
                  style: AppTextStyle.h4.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Registra los datos que necesitas consultar en tu horario.',
                  style: AppTextStyle.body.copyWith(
                    color: Theme.of(context).extension<AppColors>()!.deactive,
                  ),
                ),
                const SizedBox(height: AppSpacing.xlg),
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  decoration: _decoration(
                    label: 'Nombre de la materia',
                    hint: 'Ej. Redes de computadoras',
                    icon: Icons.menu_book_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Escribe el nombre de la materia.';
                    }

                    if (value.trim().length < 2) {
                      return 'El nombre es demasiado corto.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  maxLength: 30,
                  decoration: _decoration(
                    label: 'Clave o abreviatura',
                    hint: 'Ej. RED-901',
                    icon: Icons.tag_rounded,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _teacherController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: _decoration(
                    label: 'Docente',
                    hint: 'Nombre del profesor o profesora',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Color identificador', style: AppTextStyle.bodyBold),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final colorValue in _availableColors)
                      _SubjectColorOption(
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
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: _decoration(
                    label: 'Notas',
                    hint: 'Información adicional de la materia',
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      _isEditing ? Icons.save_rounded : Icons.add_rounded,
                    ),
                    label: Text(
                      _isEditing ? 'Guardar cambios' : 'Agregar materia',
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

class _SubjectColorOption extends StatelessWidget {
  const _SubjectColorOption({
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
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
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
