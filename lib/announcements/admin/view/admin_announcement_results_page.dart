import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rtu_mirea_app/announcements/announcements.dart';
import 'package:rtu_mirea_app/app/app.dart';
import 'package:rtu_mirea_app/institutional_profile/institutional_profile.dart';

class AdminAnnouncementResultsPage extends StatefulWidget {
  const AdminAnnouncementResultsPage({required this.announcementId, super.key});

  final String announcementId;

  @override
  State<AdminAnnouncementResultsPage> createState() =>
      _AdminAnnouncementResultsPageState();
}

class _AdminAnnouncementResultsPageState
    extends State<AdminAnnouncementResultsPage> {
  late Future<_AdminAnnouncementResultsData> _dataFuture;
  final TextEditingController _searchController = TextEditingController();

  _RecipientFilter _selectedFilter = _RecipientFilter.all;
  String _searchQuery = '';
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_AdminAnnouncementResultsData> _loadData() async {
    final repository = context.read<AnnouncementRepository>();

    final resultsFuture = repository.fetchAnnouncementResults(
      widget.announcementId,
    );

    final notificationMetricsFuture = repository
        .fetchAnnouncementNotificationMetrics(widget.announcementId);

    final results = await resultsFuture;
    final notificationMetrics = await notificationMetricsFuture;

    return _AdminAnnouncementResultsData(
      results: results,
      notificationMetrics: notificationMetrics,
    );
  }

  Future<void> _refresh() async {
    final future = _loadData();

    setState(() {
      _dataFuture = future;
    });

    await future;
  }

  List<AnnouncementResultRecipient> _filterRecipients(
    List<AnnouncementResultRecipient> recipients,
  ) {
    return recipients
        .where((recipient) {
          if (!_matchesStatusFilter(recipient)) {
            return false;
          }

          return _matchesSearchQuery(recipient);
        })
        .toList(growable: false);
  }

  bool _matchesStatusFilter(AnnouncementResultRecipient recipient) {
    return switch (_selectedFilter) {
      _RecipientFilter.all => true,
      _RecipientFilter.pending => recipient.status == 'pending',
      _RecipientFilter.edited => recipient.status == 'edited',
      _RecipientFilter.delivered => recipient.status == 'delivered',
      _RecipientFilter.seen => recipient.status == 'seen',
      _RecipientFilter.read => recipient.status == 'read',
      _RecipientFilter.confirmed => recipient.status == 'confirmed',
    };
  }

  bool _matchesSearchQuery(AnnouncementResultRecipient recipient) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    final searchableValues = <String?>[
      recipient.displayName,
      recipient.email,
      recipient.controlNumber,
      recipient.careerId,
      recipient.groupId,
      recipient.role,
    ];

    return searchableValues.any(
      (value) => value?.toLowerCase().contains(query) ?? false,
    );
  }

  void _setRecipientFilter(_RecipientFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() {
      _selectedFilter = filter;
    });
  }

  void _updateSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _exportResults({
    required Rect? sharePositionOrigin,
    required AnnouncementResults results,
    required AnnouncementNotificationMetrics notificationMetrics,
    required List<AnnouncementResultRecipient> recipients,
  }) async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final exporter = const AnnouncementResultsCsvExporter();

      final file = await exporter.export(
        results: results,
        notificationMetrics: notificationMetrics,
        recipients: recipients,
        filterLabel: _recipientFilterLabel(_selectedFilter),
        searchQuery: _searchQuery,
      );

      if (!mounted) {
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Resultados del comunicado: ${results.title}',
          text:
              'Reporte institucional de resultados del comunicado '
              '"${results.title}".',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo exportar el reporte CSV.\n$error'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!profile.canManageAnnouncements) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resultados')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xlg),
            child: Text(
              'No tienes permisos para consultar estos resultados.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados'),
        actions: [
          Builder(
            builder: (shareContext) {
              return IconButton(
                onPressed:
                    _isExporting
                        ? null
                        : () async {
                          final renderObject = shareContext.findRenderObject();
                          final renderBox =
                              renderObject is RenderBox ? renderObject : null;

                          final sharePositionOrigin =
                              renderBox == null
                                  ? null
                                  : renderBox.localToGlobal(Offset.zero) &
                                      renderBox.size;

                          final data = await _dataFuture;

                          if (!mounted) {
                            return;
                          }

                          final filteredRecipients = _filterRecipients(
                            data.results.recipients,
                          );

                          await _exportResults(
                            sharePositionOrigin: sharePositionOrigin,
                            results: data.results,
                            notificationMetrics: data.notificationMetrics,
                            recipients: filteredRecipients,
                          );
                        },
                tooltip: 'Exportar resultados CSV',
                icon:
                    _isExporting
                        ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.ios_share_outlined),
              );
            },
          ),
          IconButton(
            onPressed: _refresh,
            tooltip: 'Actualizar resultados',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_AdminAnnouncementResultsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ResultsErrorView(error: snapshot.error, onRetry: _refresh);
          }

          final data = snapshot.data;

          if (data == null) {
            return _ResultsErrorView(
              error: 'La consulta no devolvió resultados.',
              onRetry: _refresh,
            );
          }

          final results = data.results;
          final notificationMetrics = data.notificationMetrics;
          final filteredRecipients = _filterRecipients(results.recipients);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xlg,
              ),
              children: [
                _AnnouncementHeader(results: results),
                const SizedBox(height: AppSpacing.lg),
                _ResultsSummaryGrid(summary: results.summary),
                const SizedBox(height: AppSpacing.lg),
                _ProgressSection(summary: results.summary),
                const SizedBox(height: AppSpacing.lg),
                _NotificationDeliverySection(metrics: notificationMetrics),
                const SizedBox(height: AppSpacing.xlg),
                Text(
                  'Destinatarios',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${results.recipients.length} usuario(s) en la audiencia.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _searchController,
                  onChanged: _updateSearchQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, correo o número de control',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchQuery.isEmpty
                            ? null
                            : IconButton(
                              onPressed: _clearSearch,
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.clear),
                            ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _RecipientFilterBar(
                  selectedFilter: _selectedFilter,
                  summary: results.summary,
                  onSelected: _setRecipientFilter,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${filteredRecipients.length} resultado(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (results.recipients.isEmpty)
                  const _EmptyRecipientsView()
                else if (filteredRecipients.isEmpty)
                  const _NoMatchingRecipientsView()
                else
                  ...filteredRecipients.map(
                    (recipient) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _RecipientResultCard(
                        recipient: recipient,
                        contentVersion: results.contentVersion,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementHeader extends StatelessWidget {
  const _AnnouncementHeader({required this.results});

  final AnnouncementResults results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updatedAt = results.updatedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              results.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                Chip(
                  avatar: const Icon(Icons.people_outline, size: 18),
                  label: Text('Audiencia: ${results.summary.audienceTotal}'),
                ),
                Chip(
                  avatar: const Icon(Icons.history_outlined, size: 18),
                  label: Text('Versión ${results.contentVersion}'),
                ),
                Chip(
                  avatar: const Icon(Icons.info_outline, size: 18),
                  label: Text(_announcementStatusLabel(results.status)),
                ),
              ],
            ),
            if (updatedAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Última actualización: '
                '${DateFormat('dd/MM/yyyy, HH:mm', 'es_MX').format(updatedAt.toLocal())}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultsSummaryGrid extends StatelessWidget {
  const _ResultsSummaryGrid({required this.summary});

  final AnnouncementResultsSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryMetric>[
      _SummaryMetric(
        label: 'Pendientes',
        value: summary.pending,
        icon: Icons.hourglass_empty_outlined,
      ),
      _SummaryMetric(
        label: 'Editados',
        value: summary.edited,
        icon: Icons.edit_notifications_outlined,
      ),
      _SummaryMetric(
        label: 'Entregados',
        value: summary.delivered,
        icon: Icons.mark_email_unread_outlined,
      ),
      _SummaryMetric(
        label: 'Vistos',
        value: summary.seen,
        icon: Icons.visibility_outlined,
      ),
      _SummaryMetric(
        label: 'Leídos',
        value: summary.read,
        icon: Icons.done_all,
      ),
      _SummaryMetric(
        label: 'Confirmados',
        value: summary.confirmed,
        icon: Icons.verified_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _SummaryMetricCard(metric: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  const _SummaryMetricCard({required this.metric});

  final _SummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${metric.value}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(metric.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.summary});

  final AnnouncementResultsSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.audienceTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avance de lectura',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProgressRow(label: 'Vistos', value: summary.seen, total: total),
            const SizedBox(height: AppSpacing.md),
            _ProgressRow(label: 'Leídos', value: summary.read, total: total),
            const SizedBox(height: AppSpacing.md),
            _ProgressRow(
              label: 'Confirmados',
              value: summary.confirmed,
              total: total,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : value / total;
    final percentage = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$value de $total · $percentage %'),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LinearProgressIndicator(value: progress),
      ],
    );
  }
}

class _NotificationDeliverySection extends StatelessWidget {
  const _NotificationDeliverySection({required this.metrics});

  final AnnouncementNotificationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!metrics.wasRequested) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_off_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Entrega de notificación push',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'No se solicitó un envío push para la versión actual '
                'de este comunicado.',
              ),
            ],
          ),
        ),
      );
    }

    final successRate = (metrics.successRate * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Entrega de notificación push',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _NotificationDispatchStatusBadge(status: metrics.status),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Versión ${metrics.contentVersion}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - AppSpacing.md) / 2;

                final items = <_NotificationMetric>[
                  _NotificationMetric(
                    label: 'Audiencia',
                    value: metrics.audienceCount,
                    icon: Icons.people_outline,
                  ),
                  _NotificationMetric(
                    label: 'Tokens',
                    value: metrics.tokenCount,
                    icon: Icons.phonelink_ring_outlined,
                  ),
                  _NotificationMetric(
                    label: 'Enviadas',
                    value: metrics.sentCount,
                    icon: Icons.send_outlined,
                  ),
                  _NotificationMetric(
                    label: 'Fallidas',
                    value: metrics.failedCount,
                    icon: Icons.error_outline,
                  ),
                  _NotificationMetric(
                    label: 'Sin token',
                    value: metrics.noTokenCount,
                    icon: Icons.phonelink_erase_outlined,
                  ),
                  _NotificationMetric(
                    label: 'Token inválido',
                    value: metrics.invalidTokenCount,
                    icon: Icons.warning_amber_outlined,
                  ),
                ];

                return Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: itemWidth,
                          child: _NotificationMetricCard(metric: item),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(child: Text('Tasa de envío exitoso')),
                Text(
                  '${metrics.sentCount} de '
                  '${metrics.tokenCount} · $successRate %',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(value: metrics.successRate.clamp(0, 1)),
            if (metrics.startedAt != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Inicio: ${_formatNotificationDate(metrics.startedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (metrics.completedAt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Finalización: '
                '${_formatNotificationDate(metrics.completedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (metrics.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        metrics.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationMetricCard extends StatelessWidget {
  const _NotificationMetricCard({required this.metric});

  final _NotificationMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${metric.value}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(metric.label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NotificationDispatchStatusBadge extends StatelessWidget {
  const _NotificationDispatchStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, icon, backgroundColor, foregroundColor) = switch (status) {
      'processing' => (
        'Procesando',
        Icons.sync,
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      'completed' => (
        'Completado',
        Icons.check_circle_outline,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      'failed' => (
        'Fallido',
        Icons.error_outline,
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      _ => (
        'Sin solicitud',
        Icons.notifications_off_outlined,
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 18, color: foregroundColor),
      label: Text(label, style: TextStyle(color: foregroundColor)),
      backgroundColor: backgroundColor,
      side: BorderSide.none,
    );
  }
}

class _NotificationMetric {
  const _NotificationMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

String _formatNotificationDate(DateTime date) {
  return DateFormat('dd/MM/yyyy, HH:mm', 'es_MX').format(date.toLocal());
}

class _RecipientFilterBar extends StatelessWidget {
  const _RecipientFilterBar({
    required this.selectedFilter,
    required this.summary,
    required this.onSelected,
  });

  final _RecipientFilter selectedFilter;
  final AnnouncementResultsSummary summary;
  final ValueChanged<_RecipientFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = <_RecipientFilterItem>[
      _RecipientFilterItem(
        filter: _RecipientFilter.all,
        label: 'Todos',
        count: summary.audienceTotal,
      ),
      _RecipientFilterItem(
        filter: _RecipientFilter.pending,
        label: 'Pendientes',
        count: summary.pending,
      ),
      _RecipientFilterItem(
        filter: _RecipientFilter.edited,
        label: 'Editados',
        count: summary.edited,
      ),
      _RecipientFilterItem(
        filter: _RecipientFilter.delivered,
        label: 'Entregados',
        count: _exactStatusCount(
          summary: summary,
          status: _RecipientFilter.delivered,
        ),
      ),
      _RecipientFilterItem(
        filter: _RecipientFilter.seen,
        label: 'Vistos',
        count: _exactStatusCount(
          summary: summary,
          status: _RecipientFilter.seen,
        ),
      ),
      _RecipientFilterItem(
        filter: _RecipientFilter.read,
        label: 'Leídos',
        count: _exactStatusCount(
          summary: summary,
          status: _RecipientFilter.read,
        ),
      ),
      _RecipientFilterItem(
        filter: _RecipientFilter.confirmed,
        label: 'Confirmados',
        count: summary.confirmed,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  selected: selectedFilter == item.filter,
                  onSelected: (_) => onSelected(item.filter),
                  label: Text('${item.label} ${item.count}'),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _NoMatchingRecipientsView extends StatelessWidget {
  const _NoMatchingRecipientsView();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          children: [
            Icon(Icons.search_off_outlined, size: 64),
            SizedBox(height: AppSpacing.md),
            Text(
              'No hay destinatarios que coincidan con la búsqueda '
              'y el filtro seleccionados.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipientFilterItem {
  const _RecipientFilterItem({
    required this.filter,
    required this.label,
    required this.count,
  });

  final _RecipientFilter filter;
  final String label;
  final int count;
}

enum _RecipientFilter { all, pending, edited, delivered, seen, read, confirmed }

String _recipientFilterLabel(_RecipientFilter filter) {
  return switch (filter) {
    _RecipientFilter.all => 'Todos',
    _RecipientFilter.pending => 'Pendientes',
    _RecipientFilter.edited => 'Editados',
    _RecipientFilter.delivered => 'Entregados',
    _RecipientFilter.seen => 'Vistos',
    _RecipientFilter.read => 'Leídos',
    _RecipientFilter.confirmed => 'Confirmados',
  };
}

int _exactStatusCount({
  required AnnouncementResultsSummary summary,
  required _RecipientFilter status,
}) {
  final count = switch (status) {
    _RecipientFilter.delivered => summary.delivered - summary.seen,
    _RecipientFilter.seen => summary.seen - summary.read,
    _RecipientFilter.read => summary.read - summary.confirmed,
    _ => 0,
  };

  return count < 0 ? 0 : count;
}

class _RecipientResultCard extends StatelessWidget {
  const _RecipientResultCard({
    required this.recipient,
    required this.contentVersion,
  });

  final AnnouncementResultRecipient recipient;
  final int contentVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = recipient.displayName?.trim();
    final lastActivity = recipient.lastActivity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(_recipientInitials(recipient))),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty
                            ? 'Usuario sin nombre'
                            : name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _recipientAcademicDescription(recipient),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _RecipientStatusBadge(status: recipient.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (recipient.controlNumber?.trim().isNotEmpty ?? false)
                  Chip(
                    avatar: const Icon(Icons.badge_outlined, size: 18),
                    label: Text(recipient.controlNumber!),
                  ),
                if (recipient.receiptVersion != null)
                  Chip(
                    avatar: const Icon(Icons.history_outlined, size: 18),
                    label: Text(
                      'Versión ${recipient.receiptVersion}/$contentVersion',
                    ),
                  ),
              ],
            ),
            if (lastActivity != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Última actividad: '
                '${DateFormat('dd/MM/yyyy, HH:mm', 'es_MX').format(lastActivity.toLocal())}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecipientStatusBadge extends StatelessWidget {
  const _RecipientStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, icon) = switch (status) {
      'edited' => ('Editado', Icons.edit_notifications_outlined),
      'delivered' => ('Entregado', Icons.mark_email_unread_outlined),
      'seen' => ('Visto', Icons.visibility_outlined),
      'read' => ('Leído', Icons.done_all),
      'confirmed' => ('Confirmado', Icons.verified_outlined),
      _ => ('Pendiente', Icons.hourglass_empty_outlined),
    };

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor:
          status == 'confirmed'
              ? theme.colorScheme.primaryContainer
              : status == 'edited'
              ? theme.colorScheme.errorContainer
              : null,
    );
  }
}

class _EmptyRecipientsView extends StatelessWidget {
  const _EmptyRecipientsView();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64),
            SizedBox(height: AppSpacing.md),
            Text(
              'No se encontraron destinatarios para este comunicado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsErrorView extends StatelessWidget {
  const _ResultsErrorView({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No se pudieron cargar los resultados.\n$error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAnnouncementResultsData {
  const _AdminAnnouncementResultsData({
    required this.results,
    required this.notificationMetrics,
  });

  final AnnouncementResults results;
  final AnnouncementNotificationMetrics notificationMetrics;
}

class _SummaryMetric {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

String _announcementStatusLabel(String status) {
  return switch (status) {
    'draft' => 'Borrador',
    'scheduled' => 'Programado',
    'published' => 'Publicado',
    'archived' => 'Archivado',
    _ => status,
  };
}

String _recipientInitials(AnnouncementResultRecipient recipient) {
  final name = recipient.displayName?.trim();

  if (name != null && name.isNotEmpty) {
    return name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.substring(0, 1).toUpperCase())
        .join();
  }

  final controlNumber = recipient.controlNumber?.trim();

  if (controlNumber != null && controlNumber.isNotEmpty) {
    return controlNumber.substring(0, 1).toUpperCase();
  }

  return '?';
}

String _recipientAcademicDescription(AnnouncementResultRecipient recipient) {
  final parts = <String>[];

  final email = recipient.email?.trim();
  if (email != null && email.isNotEmpty) {
    parts.add(email);
  }

  final careerId = recipient.careerId;
  if (careerId != null && careerId.isNotEmpty) {
    parts.add(InstitutionalCareers.labelFor(careerId));
  }

  if (recipient.semester != null) {
    parts.add('${recipient.semester}.º semestre');
  }

  final groupId = recipient.groupId?.trim();
  if (groupId != null && groupId.isNotEmpty) {
    parts.add(groupId.toUpperCase());
  }

  return parts.isEmpty ? 'Sin información académica' : parts.join(' · ');
}
