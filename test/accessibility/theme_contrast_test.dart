import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_task.dart';
import 'package:conecta_itt/academic_planner/models/academic_task_status.dart';
import 'package:conecta_itt/academic_planner/models/task_category.dart';
import 'package:conecta_itt/academic_planner/models/task_priority.dart';
import 'package:conecta_itt/academic_planner/widgets/academic_task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance() + 0.05;
  final b = background.computeLuminance() + 0.05;
  return a > b ? a / b : b / a;
}

Color _textColor(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(
    tester.element(finder),
  ).style.merge(text.style).color!;
}

Widget _app(ThemeData theme, Widget child) =>
    MaterialApp(theme: theme, home: Scaffold(body: child));

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    final theme =
        brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
    final colors = theme.extension<AppColors>()!;

    test('$brightness: filled surfaces have readable normal text', () {
      if (brightness == Brightness.light) {
        expect(theme.colorScheme.onPrimary, Colors.white);
      }
      for (final current in [
        theme,
        AppTheme.generateTheme(colors, brightness),
      ]) {
        final scheme = current.colorScheme;
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(scheme.onError, scheme.error),
          greaterThanOrEqualTo(4.5),
        );
        final style = current.elevatedButtonTheme.style!;
        expect(
          _contrast(
            style.foregroundColor!.resolve({})!,
            style.backgroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
      final badge = theme.badgeTheme;
      if (badge.backgroundColor != null && badge.textColor != null) {
        expect(
          _contrast(badge.textColor!, badge.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    testWidgets(
      '$brightness: field errors and active boundaries are readable',
      (tester) async {
        await tester.pumpWidget(
          _app(
            theme,
            TextFormField(
              autovalidateMode: AutovalidateMode.always,
              validator: (_) => 'Revisa este campo',
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final error = _textColor(tester, find.text('Revisa este campo'));
        expect(
          _contrast(error, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
        );
        final input = theme.inputDecorationTheme;
        for (final border in [
          input.enabledBorder,
          input.focusedBorder,
          input.errorBorder,
        ]) {
          expect(
            _contrast(border!.borderSide.color, input.fillColor!),
            greaterThanOrEqualTo(3),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        '$brightness/$platform: primary label and icon remain legible',
        (tester) async {
          var presses = 0;
          await tester.pumpWidget(
            _app(
              theme.copyWith(platform: platform),
              PrimaryButton(
                text: 'Continuar',
                icon: const Icon(Icons.check),
                onPressed: () => presses++,
              ),
            ),
          );
          expect(
            _contrast(
              _textColor(tester, find.text('Continuar')),
              colors.primary,
            ),
            greaterThanOrEqualTo(4.5),
          );
          final iconColor =
              IconTheme.of(tester.element(find.byIcon(Icons.check))).color!;
          expect(_contrast(iconColor, colors.primary), greaterThanOrEqualTo(3));
          await tester.tap(find.text('Continuar'));
          expect(presses, 1);
          await tester.pumpWidget(
            _app(
              theme.copyWith(platform: platform),
              PrimaryButton(
                text: 'Continuar',
                enabled: false,
                onPressed: () => presses++,
              ),
            ),
          );
          await tester.tap(find.text('Continuar'));
          expect(presses, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '$brightness: task priority/category tags pass on tinted cards',
      (tester) async {
        final date = DateTime(2026, 1, 1);
        const labels = ['Baja', 'Media', 'Alta', 'Urgente'];
        for (final priority in TaskPriority.values) {
          await tester.pumpWidget(
            _app(
              theme,
              AcademicTaskCard(
                task: AcademicTask(
                  id: 'task',
                  title: 'Entrega',
                  priority: priority,
                  status: AcademicTaskStatus.pending,
                  createdAt: date,
                  updatedAt: date,
                  dueAt: date,
                ),
                category: TaskCategory(
                  id: 'category',
                  name: 'Laboratorio',
                  colorValue: 0xFFFFD54F,
                  createdAt: date,
                ),
                onTap: () {},
                onAction: (_) {},
              ),
            ),
          );
          for (final label in [labels[priority.index], 'Laboratorio']) {
            final finder = find.text(label);
            Color? background;
            tester.element(finder).visitAncestorElements((element) {
              final widget = element.widget;
              if (widget is Container && widget.decoration is BoxDecoration) {
                final decoration = widget.decoration! as BoxDecoration;
                if (decoration.borderRadius == BorderRadius.circular(999)) {
                  background = Color.alphaBlend(
                    decoration.color!,
                    colors.background02,
                  );
                  return false;
                }
              }
              return true;
            });
            expect(background, isNotNull);
            expect(
              _contrast(_textColor(tester, finder), background!),
              greaterThanOrEqualTo(4.5),
            );
          }
          final overdue = tester.widget<Icon>(
            find.byIcon(Icons.warning_amber_rounded),
          );
          expect(
            _contrast(overdue.color!, colors.background02),
            greaterThanOrEqualTo(3),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
