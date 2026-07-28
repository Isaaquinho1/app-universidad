import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:conecta_itt/announcements/announcements.dart';

class AnnouncementDetailView extends StatefulWidget {
  const AnnouncementDetailView({
    required this.announcement,
    this.initialAssets,
    super.key,
  });

  final Announcement announcement;
  final List<PublicationAsset>? initialAssets;

  @override
  State<AnnouncementDetailView> createState() => _AnnouncementDetailViewState();
}

class _AnnouncementDetailViewState extends State<AnnouncementDetailView> {
  late Future<List<PublicationAsset>> _assetsFuture;
  final Set<String> _openingAssetIds = {};

  Announcement get announcement => widget.announcement;

  @override
  void initState() {
    super.initState();
    _assetsFuture = _loadAssets();
  }

  @override
  void didUpdateWidget(covariant AnnouncementDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.announcement.id != widget.announcement.id ||
        oldWidget.initialAssets != widget.initialAssets) {
      _assetsFuture = _loadAssets();
    }
  }

  Future<List<PublicationAsset>> _loadAssets() async {
    final initialAssets = widget.initialAssets;

    if (initialAssets != null) {
      return List<PublicationAsset>.unmodifiable(initialAssets);
    }

    return context.read<PublicationAssetRepository>().fetchAssets(
      publicationId: announcement.id,
    );
  }

  Future<void> _retryAssets() async {
    setState(() {
      _assetsFuture = context.read<PublicationAssetRepository>().fetchAssets(
        publicationId: announcement.id,
      );
    });
  }

  Future<void> _openAttachment(PublicationAsset asset) async {
    if (_openingAssetIds.contains(asset.id)) {
      return;
    }

    setState(() {
      _openingAssetIds.add(asset.id);
    });

    try {
      await context.read<PublicationAssetRepository>().downloadAndOpenAsset(
        asset,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir "${asset.originalName}": $error'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _openingAssetIds.remove(asset.id);
        });
      }
    }
  }

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
            child: FutureBuilder<List<PublicationAsset>>(
              future: _assetsFuture,
              builder: (context, assetsSnapshot) {
                final assets =
                    assetsSnapshot.data ??
                    widget.initialAssets ??
                    const <PublicationAsset>[];

                final cover = _findCover(assets);
                final gallery = assets
                    .where((asset) => asset.type == PublicationAssetType.image)
                    .toList(growable: false);
                final attachments = assets
                    .where((asset) => asset.type.isAttachment)
                    .toList(growable: false);

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cover != null)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: PublicationAssetImage(
                            asset: cover,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _AnnouncementStatusHeader(
                              priority: announcement.priority,
                              receipt: state.receipt,
                              contentVersion: announcement.contentVersion,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              announcement.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_circle_outlined,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    announcement.authorName ??
                                        'TecNM Campus Tlalpan',
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
                            if (gallery.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xlg),
                              Text(
                                'Galería',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                height: 180,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: gallery.length,
                                  separatorBuilder:
                                      (_, _) =>
                                          const SizedBox(width: AppSpacing.sm),
                                  itemBuilder: (context, index) {
                                    final asset = gallery[index];

                                    return PublicationAssetImage(
                                      asset: asset,
                                      width: 260,
                                      height: 180,
                                      fit: BoxFit.cover,
                                      borderRadius: BorderRadius.circular(12),
                                    );
                                  },
                                ),
                              ),
                            ],
                            if (attachments.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xlg),
                              Text(
                                'Archivos adjuntos',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ...attachments.map(
                                (asset) => _buildAttachmentTile(context, asset),
                              ),
                            ],
                            if (assetsSnapshot.hasError) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'No se pudo cargar el '
                                        'contenido multimedia.',
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      TextButton.icon(
                                        onPressed: _retryAssets,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Reintentar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (assetsSnapshot.connectionState !=
                                    ConnectionState.done &&
                                assets.isEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              const Center(child: CircularProgressIndicator()),
                            ],
                            const SizedBox(height: AppSpacing.xlg),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.green.shade200,
                                  disabledForegroundColor: Colors.white,
                                ),
                                onPressed:
                                    state.isRead &&
                                            !state.isConfirmed &&
                                            !isConfirming
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
                                'La confirmación estará disponible '
                                'después de leer el comunicado.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentTile(BuildContext context, PublicationAsset asset) {
    final isOpening = _openingAssetIds.contains(asset.id);

    return Card(
      child: ListTile(
        leading: Icon(
          asset.isPdf
              ? Icons.picture_as_pdf_outlined
              : Icons.description_outlined,
        ),
        title: Text(
          asset.originalName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${asset.extension.toUpperCase()} · '
          '${_formatFileSize(asset.sizeBytes)}',
        ),
        trailing:
            isOpening
                ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.open_in_new),
        onTap: isOpening ? null : () => _openAttachment(asset),
      ),
    );
  }

  PublicationAsset? _findCover(List<PublicationAsset> assets) {
    for (final asset in assets) {
      if (asset.type.isCover) {
        return asset;
      }
    }

    return null;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kilobytes = bytes / 1024;

    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1)} MB';
  }
}

class _AnnouncementStatusHeader extends StatelessWidget {
  const _AnnouncementStatusHeader({
    required this.priority,
    required this.receipt,
    required this.contentVersion,
  });

  final AnnouncementPriority priority;
  final AnnouncementReceipt? receipt;
  final int contentVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (
      priorityLabel,
      priorityBackground,
      priorityForeground,
      priorityBorder,
    ) = switch (priority) {
      AnnouncementPriority.low => (
        'Prioridad baja',
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outlineVariant,
      ),
      AnnouncementPriority.normal => (
        'Prioridad normal',
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outlineVariant,
      ),
      AnnouncementPriority.high => (
        'Importante',
        Colors.amber.shade400,
        Colors.white,
        Colors.transparent,
      ),
      AnnouncementPriority.urgent => (
        'Urgente',
        Colors.red.shade700,
        Colors.white,
        Colors.transparent,
      ),
    };

    final isEdited =
        receipt != null && receipt!.receiptVersion < contentVersion;

    final statusLabel =
        isEdited
            ? 'Editado'
            : switch (receipt?.status) {
              AnnouncementReceiptStatus.delivered => 'Entregado',
              AnnouncementReceiptStatus.seen => 'Visto',
              AnnouncementReceiptStatus.read => 'Leído',
              AnnouncementReceiptStatus.confirmed => 'Confirmado',
              null => 'Registrando apertura',
            };

    final (statusBackground, statusForeground, statusBorder, statusIcon) =
        isEdited
            ? (
              Colors.orange.shade700,
              Colors.white,
              Colors.transparent,
              Icons.edit_notifications_outlined,
            )
            : switch (receipt?.status) {
              AnnouncementReceiptStatus.confirmed => (
                Colors.green.shade700,
                Colors.white,
                Colors.transparent,
                Icons.verified_outlined,
              ),
              AnnouncementReceiptStatus.read => (
                theme.colorScheme.surface,
                Colors.blue.shade700,
                Colors.blue.shade200,
                Icons.done_all,
              ),
              AnnouncementReceiptStatus.seen => (
                theme.colorScheme.secondaryContainer,
                theme.colorScheme.onSecondaryContainer,
                Colors.transparent,
                Icons.visibility_outlined,
              ),
              AnnouncementReceiptStatus.delivered || null => (
                theme.colorScheme.primaryContainer,
                theme.colorScheme.onPrimaryContainer,
                Colors.transparent,
                Icons.fiber_new_outlined,
              ),
            };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _DetailBadge(
          label: priorityLabel,
          icon: Icons.campaign_outlined,
          backgroundColor: priorityBackground,
          foregroundColor: priorityForeground,
          borderColor: priorityBorder,
        ),
        _DetailBadge(
          label: statusLabel,
          icon: statusIcon,
          backgroundColor: statusBackground,
          foregroundColor: statusForeground,
          borderColor: statusBorder,
        ),
      ],
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border:
            borderColor == Colors.transparent
                ? null
                : Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
