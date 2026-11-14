import 'package:conecta_itt/announcements/admin/models/announcement_navigation_result.dart';
import 'package:conecta_itt/announcements/admin/view/admin_announcement_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> verifyDialog(
    WidgetTester tester, {
    required String message,
    required String expectedTitle,
    required AnnouncementNavigationStatus status,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder:
                        (_) => AdminAnnouncementResultDialog(
                          title:
                              AnnouncementNavigationResult(
                                message: message,
                                status: status,
                              ).title,
                          message: message,
                        ),
                  );
                },
                child: const Text('Mostrar resultado'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar resultado'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(expectedTitle), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Aceptar'), findsOneWidget);

    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  }

  testWidgets('Guardado exitoso muestra confirmacion', (tester) async {
    await verifyDialog(
      tester,
      message: 'Noticia publicada correctamente.',
      expectedTitle: 'Operación completada',
      status: AnnouncementNavigationStatus.success,
    );
  });

  testWidgets('Fallo FCM muestra advertencia administrativa', (tester) async {
    await verifyDialog(
      tester,
      message:
          'Noticia publicada correctamente. '
          'Advertencia: los cambios se guardaron, '
          'pero no se pudo confirmar el resultado de FCM.',
      expectedTitle: 'Publicación guardada con advertencia',
      status: AnnouncementNavigationStatus.notificationWarning,
    );
  });

  testWidgets('FCM parcial muestra advertencia administrativa', (tester) async {
    await verifyDialog(
      tester,
      message:
          'Comunicado actualizado correctamente. '
          'Advertencia: FCM informó 2 envío(s) fallido(s).',
      expectedTitle: 'Publicación guardada con advertencia',
      status: AnnouncementNavigationStatus.notificationWarning,
    );
  });

  testWidgets('Advertencia independiente del texto', (tester) async {
    await verifyDialog(
      tester,
      message: 'La publicación fue guardada. Revisar el despacho.',
      expectedTitle: 'Publicación guardada con advertencia',
      status: AnnouncementNavigationStatus.notificationWarning,
    );
  });
}
