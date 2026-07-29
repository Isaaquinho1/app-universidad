import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/app/app.dart';

/// Loads a visible institutional announcement from its identifier.
///
/// The repository remains the source of truth for audience segmentation:
/// announcements outside the authenticated user's audience are returned as
/// unavailable.
class AnnouncementDetailPage extends StatefulWidget {
  const AnnouncementDetailPage({required this.announcementId, super.key});

  final String announcementId;

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  late Future<Announcement?> _announcementFuture;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  void _loadAnnouncement() {
    _announcementFuture = context
        .read<AnnouncementRepository>()
        .fetchAnnouncement(widget.announcementId);
  }

  void _retry() {
    setState(_loadAnnouncement);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comunicado')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No se encontró un perfil institucional activo.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return FutureBuilder<Announcement?>(
      future: _announcementFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Comunicado')),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Comunicado')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'No se pudo cargar el comunicado.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final announcement = snapshot.data;

        if (announcement == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Comunicado')),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 48),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Este comunicado no está disponible o no pertenece '
                      'a tu audiencia.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (announcement.isNews) {
          return AnnouncementDetailView(announcement: announcement);
        }

        return BlocProvider(
          create:
              (_) => AnnouncementReceiptCubit(
                repository: context.read<AnnouncementRepository>(),
                announcementId: announcement.id,
                userUid: profile.uid,
                contentVersion: announcement.contentVersion,
              )..started(),
          child: AnnouncementDetailView(announcement: announcement),
        );
      },
    );
  }
}
