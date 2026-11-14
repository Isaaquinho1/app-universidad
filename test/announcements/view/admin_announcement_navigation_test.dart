import 'package:conecta_itt/announcements/admin/models/announcement_navigation_result.dart';
import 'package:conecta_itt/announcements/admin/view/admin_announcement_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> verifyNavigation(
    WidgetTester tester, {
    required AnnouncementNavigationResult result,
    required String expectedTitle,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      final navigationResult = await context
                          .push<AnnouncementNavigationResult>('/form');

                      if (!context.mounted || navigationResult == null) {
                        return;
                      }

                      await showDialog<void>(
                        context: context,
                        builder:
                            (_) => AdminAnnouncementResultDialog(
                              title: navigationResult.title,
                              message: navigationResult.message,
                            ),
                      );
                    },
                    child: const Text('Abrir formulario'),
                  ),
                ),
              ),
        ),
        GoRoute(
          path: '/form',
          builder:
              (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      context.pop(result);
                    },
                    child: const Text('Guardar y regresar'),
                  ),
                ),
              ),
        ),
      ],
    );

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar y regresar'), findsOneWidget);

    await tester.tap(find.text('Guardar y regresar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(expectedTitle), findsOneWidget);
    expect(find.text(result.message), findsOneWidget);

    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Abrir formulario'), findsOneWidget);
  }

  testWidgets('GoRouter devuelve un resultado exitoso', (tester) async {
    await verifyNavigation(
      tester,
      result: const AnnouncementNavigationResult(
        message: 'Noticia publicada correctamente.',
        status: AnnouncementNavigationStatus.success,
      ),
      expectedTitle: 'Operación completada',
    );
  });

  testWidgets('GoRouter conserva la advertencia FCM', (tester) async {
    await verifyNavigation(
      tester,
      result: const AnnouncementNavigationResult(
        message: 'Publicación guardada. Revisar notificaciones.',
        status: AnnouncementNavigationStatus.notificationWarning,
      ),
      expectedTitle: 'Publicación guardada con advertencia',
    );
  });
}
