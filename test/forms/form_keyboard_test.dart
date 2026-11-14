import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_subject_form_sheet.dart';
import 'package:conecta_itt/academic_planner/widgets/class_session_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, TargetPlatform platform) => MaterialApp(
  theme: ThemeData(
    platform: platform,
    extensions: const <ThemeExtension<dynamic>>[AppColors.light],
  ),
  home: Scaffold(body: child),
);

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

EditableText _editable(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform: next advances, done dismisses and retains text', (
      tester,
    ) async {
      final email = TextEditingController();
      final password = TextEditingController();
      addTearDown(email.dispose);
      addTearDown(password.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              LabelledInput(
                label: 'Correo',
                controller: email,
                textInputAction: TextInputAction.next,
              ),
              LabelledInput(
                label: 'Contraseña',
                controller: password,
                obscureText: true,
                showPasswordToggle: true,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          platform,
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'estudiante@tlalpan.tecnm.mx');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(_editable(tester, fields.last).focusNode.hasFocus, isTrue);
      await tester.enterText(fields.last, 'Clave123');
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      expect(_editable(tester, fields.last).focusNode.hasFocus, isTrue);
      expect(_editable(tester, fields.last).obscureText, isFalse);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(_editable(tester, fields.last).focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(email.text, 'estudiante@tlalpan.tecnm.mx');
      expect(password.text, 'Clave123');
    });

    testWidgets('$platform: touching free space dismisses without clearing', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              LabelledInput(label: 'Nombre', controller: controller),
              Expanded(
                child: GestureDetector(
                  key: const Key('freeSpace'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
          platform,
        ),
      );
      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.tap(find.byKey(const Key('freeSpace')));
      await tester.pump();
      expect(
        _editable(tester, find.byType(TextField)).focusNode.hasFocus,
        isFalse,
      );
      expect(controller.text, 'Ana');
    });

    testWidgets('$platform: session next and done keep the form open', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ClassSessionFormSheet(), platform));
      await tester.enterText(_field('Edificio'), 'A');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(
        _editable(tester, _field('Salón o aula')).focusNode.hasFocus,
        isTrue,
      );
      await tester.enterText(_field('Salón o aula'), 'A-101');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        _editable(tester, _field('Salón o aula')).focusNode.hasFocus,
        isFalse,
      );
      expect(find.byType(ClassSessionFormSheet), findsOneWidget);
      expect(_editable(tester, _field('Edificio')).controller.text, 'A');
      expect(
        _editable(tester, _field('Salón o aula')).controller.text,
        'A-101',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$platform: subject next reaches notes and preserves newlines',
      (tester) async {
        await tester.pumpWidget(
          _app(const AcademicSubjectFormSheet(), platform),
        );
        await tester.ensureVisible(_field('Docente'));
        await tester.enterText(_field('Docente'), 'Profesora Ana');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(_editable(tester, _field('Notas')).focusNode.hasFocus, isTrue);
        await tester.enterText(_field('Notas'), 'Línea uno\nLínea dos');
        expect(
          tester.testTextInput.setClientArgs?['inputAction'],
          'TextInputAction.newline',
        );
        expect(
          _editable(tester, _field('Notas')).controller.text,
          'Línea uno\nLínea dos',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$platform: save remains reachable with the keyboard inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        _app(
          Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const ClassSessionFormSheet(),
                      ),
                  child: const Text('Abrir'),
                ),
          ),
          platform,
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final save = find.ancestor(
        of: find.text('Agregar sesión'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
