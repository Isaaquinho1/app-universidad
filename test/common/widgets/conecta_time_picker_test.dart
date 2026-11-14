import 'package:conecta_itt/common/widgets/conecta_time_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openPicker(
    WidgetTester tester, {
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay?> onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    final result = await showConectaTimePicker(
                      context: context,
                      initialTime: initial,
                      helpText: 'Seleccionar hora',
                    );
                    onResult(result);
                  },
                  child: const Text('Abrir selector'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra la hora inicial correctamente', (tester) async {
    await openPicker(
      tester,
      initial: const TimeOfDay(hour: 8, minute: 30),
      onResult: (_) {},
    );

    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    expect(find.text('Horas'), findsOneWidget);
    expect(find.text('Minutos'), findsOneWidget);
    expect(find.text('Aplicar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    final hours = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('conecta-time-hours')),
    );

    final minutes = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('conecta-time-minutes')),
    );

    expect(hours.scrollController!.selectedItem, 8);
    expect(minutes.scrollController!.selectedItem, 30);
  });

  testWidgets('cancelar devuelve null', (tester) async {
    TimeOfDay? result = const TimeOfDay(hour: 1, minute: 1);
    var completed = false;

    await openPicker(
      tester,
      initial: const TimeOfDay(hour: 10, minute: 15),
      onResult: (value) {
        result = value;
        completed = true;
      },
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('aplicar conserva la hora seleccionada', (tester) async {
    TimeOfDay? result;

    await openPicker(
      tester,
      initial: const TimeOfDay(hour: 23, minute: 59),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(result, const TimeOfDay(hour: 23, minute: 59));
  });

  testWidgets('permite cambiar horas y minutos', (tester) async {
    TimeOfDay? result;

    await openPicker(
      tester,
      initial: const TimeOfDay(hour: 8, minute: 30),
      onResult: (value) => result = value,
    );

    await tester.drag(
      find.byKey(const ValueKey('conecta-time-hours')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('conecta-time-minutes')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();

    final hours = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('conecta-time-hours')),
    );
    final minutes = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('conecta-time-minutes')),
    );

    final expectedHour = hours.scrollController!.selectedItem;
    final expectedMinute = minutes.scrollController!.selectedItem;

    expect(expectedHour, isNot(8));
    expect(expectedMinute, isNot(30));

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(result, TimeOfDay(hour: expectedHour, minute: expectedMinute));
  });
}
