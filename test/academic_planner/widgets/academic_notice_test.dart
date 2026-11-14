import 'package:conecta_itt/academic_planner/widgets/academic_notice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android muestra el aviso mediante SnackBar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () {
                      AcademicNotice.show(
                        context,
                        message: 'Recordatorio académico',
                      );
                    },
                    child: const Text('Mostrar aviso'),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mostrar aviso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Recordatorio académico'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS muestra el aviso con CupertinoPopupSurface', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder:
                  (context) => Center(
                    child: CupertinoButton(
                      onPressed: () {
                        AcademicNotice.show(
                          context,
                          message: 'Aviso académico iOS',
                        );
                      },
                      child: const Text('Mostrar aviso'),
                    ),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mostrar aviso'));
      await tester.pump();

      expect(find.byType(CupertinoPopupSurface), findsOneWidget);
      expect(find.text('Aviso académico iOS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('Aviso académico iOS'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS no falla si se desmonta la pantalla', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder:
                  (context) => CupertinoButton(
                    onPressed: () {
                      AcademicNotice.show(context, message: 'Aviso temporal');
                    },
                    child: const Text('Mostrar aviso'),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mostrar aviso'));
      await tester.pump();

      expect(find.text('Aviso temporal'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
