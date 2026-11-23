import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Consulta del texto íntegro de un documento legal incluido en la app.
///
/// La presentación de un documento no registra por sí sola
/// la aceptación ni sustituye la validación del backend.
class LegalDocumentViewer extends StatelessWidget {
  const LegalDocumentViewer({
    required this.title,
    required this.assetPath,
    super.key,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No fue posible cargar el documento. '
                  'Inténtalo nuevamente.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  snapshot.data!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.65),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
