import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/announcements/announcements.dart';

class AdminAnnouncementEditPage extends StatelessWidget {
  const AdminAnnouncementEditPage({required this.announcementId, super.key});

  final String announcementId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Announcement?>(
      future: context.read<AnnouncementRepository>().fetchAdminAnnouncement(
        announcementId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar comunicado')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar comunicado')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xlg),
                child: Text(
                  'No se pudo cargar el comunicado.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final announcement = snapshot.data;

        if (announcement == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Editar comunicado')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xlg),
                child: Text(
                  'El comunicado solicitado no existe o ya no está disponible.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return AdminAnnouncementCreatePage(initialAnnouncement: announcement);
      },
    );
  }
}
