import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:rtu_mirea_app/announcements/announcements.dart';

class AnnouncementDetailView extends StatelessWidget {
  const AnnouncementDetailView({required this.announcement, super.key});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AnnouncementReceiptCubit, AnnouncementReceiptState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status &&
              current.status == AnnouncementReceiptOperationStatus.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('No se pudo actualizar el estado de lectura.'),
            ),
          );
      },
      builder: (context, state) {
        final publishedAt = announcement.publishedAt;
        final isConfirming =
            state.status == AnnouncementReceiptOperationStatus.confirming;

        return Scaffold(
          appBar: AppBar(title: const Text('Comunicado')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnnouncementStatusHeader(
                    priority: announcement.priority,
                    receipt: state.receipt,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          announcement.authorName ?? 'TecNM Campus Tlalpan',
                        ),
                      ),
                    ],
                  ),
                  if (publishedAt != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.schedule_outlined, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy, HH:mm',
                          ).format(publishedAt.toLocal()),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xlg),
                  SelectableText(
                    announcement.body,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  if (announcement.attachmentUrls.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xlg),
                    Text(
                      'Archivos adjuntos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...announcement.attachmentUrls.map(
                      (url) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file),
                        title: Text(
                          url,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xlg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          state.isRead && !state.isConfirmed && !isConfirming
                              ? () {
                                context
                                    .read<AnnouncementReceiptCubit>()
                                    .confirmReading();
                              }
                              : null,
                      icon:
                          isConfirming
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                state.isConfirmed
                                    ? Icons.verified_outlined
                                    : Icons.task_alt_outlined,
                              ),
                      label: Text(
                        state.isConfirmed
                            ? 'Lectura confirmada'
                            : state.isRead
                            ? 'Confirmar lectura'
                            : 'Leyendo comunicado…',
                      ),
                    ),
                  ),
                  if (!state.isRead) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'La confirmación estará disponible después de leer '
                      'el comunicado.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnnouncementStatusHeader extends StatelessWidget {
  const _AnnouncementStatusHeader({
    required this.priority,
    required this.receipt,
  });

  final AnnouncementPriority priority;
  final AnnouncementReceipt? receipt;

  @override
  Widget build(BuildContext context) {
    final priorityLabel = switch (priority) {
      AnnouncementPriority.low => 'Prioridad baja',
      AnnouncementPriority.normal => 'Prioridad normal',
      AnnouncementPriority.high => 'Importante',
      AnnouncementPriority.urgent => 'Urgente',
    };

    final statusLabel = switch (receipt?.status) {
      AnnouncementReceiptStatus.delivered => 'Entregado',
      AnnouncementReceiptStatus.seen => 'Visto',
      AnnouncementReceiptStatus.read => 'Leído',
      AnnouncementReceiptStatus.confirmed => 'Confirmado',
      null => 'Registrando apertura',
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        Chip(
          avatar: const Icon(Icons.campaign_outlined, size: 18),
          label: Text(priorityLabel),
        ),
        Chip(
          avatar: Icon(
            receipt?.isConfirmed ?? false
                ? Icons.verified_outlined
                : Icons.visibility_outlined,
            size: 18,
          ),
          label: Text(statusLabel),
        ),
      ],
    );
  }
}
