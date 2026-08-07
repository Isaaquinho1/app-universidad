import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:flutter/material.dart';

class ClassSessionFormData {
  const ClassSessionFormData({
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    this.building,
    this.room,
    this.reminderMinutes,
  });

  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final String? building;
  final String? room;
  final int? reminderMinutes;
}

class ClassSessionFormSheet extends StatefulWidget {
  const ClassSessionFormSheet({super.key, this.session});

  final ClassSession? session;

  @override
  State<ClassSessionFormSheet> createState() => _ClassSessionFormSheetState();
}

class _ClassSessionFormSheetState extends State<ClassSessionFormSheet> {
  static const _weekdays = <int, String>{
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  static const _reminderOptions = <int?, String>{
    null: 'Sin recordatorio',
    5: '5 minutos antes',
    10: '10 minutos antes',
    15: '15 minutos antes',
    30: '30 minutos antes',
    60: '1 hora antes',
  };

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _buildingController;
  late final TextEditingController _roomController;

  late int _weekday;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  int? _reminderMinutes;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();

    final session = widget.session;

    _weekday = session?.weekday ?? DateTime.monday;
    _startTime = _minutesToTime(session?.startMinutes ?? 8 * 60);
    _endTime = _minutesToTime(session?.endMinutes ?? 10 * 60);
    _reminderMinutes = session?.reminderMinutes;

    _buildingController = TextEditingController(text: session?.building ?? '');
    _roomController = TextEditingController(text: session?.room ?? '');
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  TimeOfDay _minutesToTime(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  String? _normalizeOptional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _selectStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Hora de inicio',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _startTime = selected;
    });
  }

  Future<void> _selectEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: 'Hora de término',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _endTime = selected;
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final startMinutes = _timeToMinutes(_startTime);
    final endMinutes = _timeToMinutes(_endTime);

    if (endMinutes <= startMinutes) {
      showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              icon: const Icon(Icons.schedule_rounded),
              title: const Text('Horario no válido'),
              content: const Text(
                'La hora de término debe ser posterior a la hora de inicio.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
      );
      return;
    }

    Navigator.of(context).pop(
      ClassSessionFormData(
        weekday: _weekday,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        building: _normalizeOptional(_buildingController.text),
        room: _normalizeOptional(_roomController.text),
        reminderMinutes: _reminderMinutes,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final colors = Theme.of(context).extension<AppColors>()!;

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
                  _isEditing ? 'Editar sesión' : 'Nueva sesión de clase',
                  style: AppTextStyle.h4.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Selecciona el día, horario y ubicación de la clase.',
                  style: AppTextStyle.body.copyWith(color: colors.deactive),
                ),
                const SizedBox(height: AppSpacing.xlg),
                DropdownButtonFormField<int>(
                  initialValue: _weekday,
                  decoration: _decoration(
                    label: 'Día de la semana',
                    icon: Icons.calendar_today_outlined,
                  ),
                  items: [
                    for (final entry in _weekdays.entries)
                      DropdownMenuItem<int>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _weekday = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Inicio',
                        value: _startTime,
                        onTap: _selectStartTime,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TimeField(
                        label: 'Término',
                        value: _endTime,
                        onTap: _selectEndTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _buildingController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  decoration: _decoration(
                    label: 'Edificio',
                    hint: 'Ej. Edificio A',
                    icon: Icons.apartment_rounded,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _roomController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  maxLength: 40,
                  decoration: _decoration(
                    label: 'Salón o aula',
                    hint: 'Ej. A-101',
                    icon: Icons.meeting_room_outlined,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int?>(
                  initialValue: _reminderMinutes,
                  decoration: _decoration(
                    label: 'Recordatorio',
                    icon: Icons.notifications_outlined,
                  ),
                  items: [
                    for (final entry in _reminderOptions.entries)
                      DropdownMenuItem<int?>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _reminderMinutes = value;
                    });
                  },
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
                      _isEditing ? 'Guardar cambios' : 'Agregar sesión',
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

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_rounded),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(value.format(context), style: AppTextStyle.bodyBold),
      ),
    );
  }
}
