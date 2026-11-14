import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Abre un selector de horas y minutos con ruedas independientes.
///
/// Devuelve null si se cancela, sin modificar el valor original.
Future<TimeOfDay?> showConectaTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder:
        (dialogContext) => _ConectaTimePickerDialog(
          initialTime: initialTime,
          title: helpText ?? 'Seleccionar hora',
        ),
  );
}

class _ConectaTimePickerDialog extends StatefulWidget {
  const _ConectaTimePickerDialog({
    required this.initialTime,
    required this.title,
  });

  final TimeOfDay initialTime;
  final String title;

  @override
  State<_ConectaTimePickerDialog> createState() =>
      _ConectaTimePickerDialogState();
}

class _ConectaTimePickerDialogState extends State<_ConectaTimePickerDialog> {
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();

    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;

    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;

    Widget wheel({
      required String keyName,
      required int count,
      required FixedExtentScrollController controller,
      required ValueChanged<int> onChanged,
    }) {
      return Expanded(
        child: CupertinoPicker(
          key: ValueKey(keyName),
          scrollController: controller,
          itemExtent: 40,
          diameterRatio: 1.35,
          squeeze: 1.1,
          useMagnifier: true,
          magnification: 1.08,
          onSelectedItemChanged: onChanged,
          children: List.generate(
            count,
            (index) => Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: foreground,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 290,
        height: 215,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text('Horas', style: theme.textTheme.labelMedium),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Center(
                    child: Text('Minutos', style: theme.textTheme.labelMedium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  wheel(
                    keyName: 'conecta-time-hours',
                    count: 24,
                    controller: _hourController,
                    onChanged: (value) {
                      _hour = value;
                    },
                  ),
                  Text(
                    ':',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  wheel(
                    keyName: 'conecta-time-minutes',
                    count: 60,
                    controller: _minuteController,
                    onChanged: (value) {
                      _minute = value;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute));
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
