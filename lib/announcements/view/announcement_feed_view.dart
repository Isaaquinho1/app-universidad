import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/app/app.dart';

/// Connects the institutional profile with the segmented announcement feed.
class AnnouncementCategoryFeed extends StatelessWidget {
  const AnnouncementCategoryFeed({this.scrollController, super.key});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppBloc>().state;
    final profile = appState.institutionalProfile;

    if (!appState.status.isLoggedIn) {
      return const _InstitutionalProfileRequiredView();
    }

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return BlocProvider(
      key: ValueKey('announcement-feed-${profile.uid}-${profile.updatedAt}'),
      create:
          (context) => AnnouncementBloc(
            repository: context.read<AnnouncementRepository>(),
            assetRepository: context.read<PublicationAssetRepository>(),
            profile: profile,
          )..add(const AnnouncementsStarted()),
      child: AnnouncementFeedView(scrollController: scrollController),
    );
  }
}

enum _PublicationFeedFilter {
  all,
  news,
  announcements;

  String get label {
    return switch (this) {
      _PublicationFeedFilter.all => 'Todo',
      _PublicationFeedFilter.news => 'Noticias',
      _PublicationFeedFilter.announcements => 'Comunicados',
    };
  }

  bool accepts(Announcement publication) {
    return switch (this) {
      _PublicationFeedFilter.all => true,
      _PublicationFeedFilter.news => publication.isNews,
      _PublicationFeedFilter.announcements => publication.isAnnouncement,
    };
  }
}

/// Displays institutional news and segmented announcements.
class AnnouncementFeedView extends StatefulWidget {
  const AnnouncementFeedView({this.scrollController, super.key});

  final ScrollController? scrollController;

  @override
  State<AnnouncementFeedView> createState() => _AnnouncementFeedViewState();
}

class _AnnouncementFeedViewState extends State<AnnouncementFeedView> {
  _PublicationFeedFilter _filter = _PublicationFeedFilter.all;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        switch (state.status) {
          case AnnouncementsStatus.initial:
          case AnnouncementsStatus.loading:
            return const Center(child: CircularProgressIndicator());

          case AnnouncementsStatus.failure:
            return FailureScreen(
              title: 'Error de carga',
              description:
                  'No se pudieron cargar las publicaciones institucionales.',
              icon: Icons.campaign_outlined,
              buttonText: 'Reintentar',
              onButtonPressed: () {
                context.read<AnnouncementBloc>().add(
                  const AnnouncementsStarted(),
                );
              },
            );

          case AnnouncementsStatus.populated:
            final publications = state.announcements
                .where(_filter.accepts)
                .toList(growable: false);

            if (state.announcements.isEmpty) {
              return const _EmptyAnnouncementsView(
                filter: _PublicationFeedFilter.all,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnnouncementBloc>().add(
                  const AnnouncementsStarted(),
                );

                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                controller: widget.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SegmentedButton<_PublicationFeedFilter>(
                        segments: _PublicationFeedFilter.values
                            .map(
                              (filter) => ButtonSegment(
                                value: filter,
                                label: Text(filter.label),
                              ),
                            )
                            .toList(growable: false),
                        selected: {_filter},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          setState(() {
                            _filter = selection.first;
                          });
                        },
                      ),
                    ),
                  ),
                  if (publications.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyAnnouncementsView(filter: _filter),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      sliver: SliverList.separated(
                        itemCount: publications.length,
                        itemBuilder: (context, index) {
                          final announcement = publications[index];

                          return AnnouncementCard(
                            announcement: announcement,
                            receipt:
                                state.receiptsByAnnouncementId[announcement.id],
                            assets:
                                state.assetsByAnnouncementId[announcement.id] ??
                                const [],
                          );
                        },
                        separatorBuilder:
                            (_, _) => const SizedBox(height: AppSpacing.md),
                      ),
                    ),
                ],
              ),
            );
        }
      },
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    required this.announcement,
    this.receipt,
    this.assets = const [],
    super.key,
  });

  final Announcement announcement;
  final AnnouncementReceipt? receipt;
  final List<PublicationAsset> assets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description =
        announcement.summary?.trim().isNotEmpty ?? false
            ? announcement.summary!
            : announcement.body;
    final cover = _coverAsset;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: announcement.isCurrentlyFeatured ? 4 : null,
      child: InkWell(
        onTap: () async {
          final appState = context.read<AppBloc>().state;
          final profile = appState.institutionalProfile;

          if (profile == null) {
            return;
          }

          final repository = context.read<AnnouncementRepository>();

          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder:
                  (_) => MultiRepositoryProvider(
                    providers: [
                      RepositoryProvider<AnnouncementRepository>.value(
                        value: repository,
                      ),
                      RepositoryProvider<PublicationAssetRepository>.value(
                        value: context.read<PublicationAssetRepository>(),
                      ),
                    ],
                    child:
                        announcement.isAnnouncement
                            ? BlocProvider(
                              create:
                                  (_) => AnnouncementReceiptCubit(
                                    repository: repository,
                                    announcementId: announcement.id,
                                    userUid: profile.uid,
                                    contentVersion: announcement.contentVersion,
                                  )..started(),
                              child: AnnouncementDetailView(
                                announcement: announcement,
                                initialAssets: assets,
                              ),
                            )
                            : AnnouncementDetailView(
                              announcement: announcement,
                              initialAssets: assets,
                            ),
                  ),
            ),
          );

          if (!context.mounted) {
            return;
          }

          context.read<AnnouncementBloc>().add(const AnnouncementsStarted());
        },
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
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PublicationTypeBadge(announcement: announcement),
                      if (announcement.isNews &&
                          announcement.newsCategory?.trim().isNotEmpty == true)
                        _NewsCategoryBadge(
                          category: announcement.newsCategory!.trim(),
                        ),
                      if (announcement.isCurrentlyFeatured)
                        const _FeaturedBadge(),
                      if (announcement.isAnnouncement) ...[
                        _PriorityBadge(priority: announcement.priority),
                        _ReceiptBadge(
                          receipt: receipt,
                          contentVersion: announcement.contentVersion,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    announcement.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          announcement.authorName ?? 'TecNM Campus Tlalpan',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (_attachmentCount > 0) ...[
                        const Icon(Icons.attach_file, size: 18),
                        Text(
                          '$_attachmentCount',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _attachmentCount {
    return assets.where((asset) => asset.type.isAttachment).length;
  }

  PublicationAsset? get _coverAsset {
    for (final asset in assets) {
      if (asset.type.isCover) {
        return asset;
      }
    }

    return null;
  }
}

class _PublicationTypeBadge extends StatelessWidget {
  const _PublicationTypeBadge({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNews = announcement.isNews;

    return _FeedBadge(
      label: isNews ? 'Noticia' : 'Comunicado',
      icon: isNews ? Icons.newspaper_outlined : Icons.campaign_outlined,
      backgroundColor:
          isNews
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
      foregroundColor:
          isNews
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onPrimaryContainer,
    );
  }
}

class _NewsCategoryBadge extends StatelessWidget {
  const _NewsCategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _FeedBadge(
      label: category,
      icon: Icons.sell_outlined,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      foregroundColor: theme.colorScheme.onSurfaceVariant,
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    return _FeedBadge(
      label: 'Destacada',
      icon: Icons.star_rounded,
      backgroundColor: Colors.amber.shade800,
      foregroundColor: Colors.white,
    );
  }
}

class _FeedBadge extends StatelessWidget {
  const _FeedBadge({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foregroundColor),
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

class _ReceiptBadge extends StatelessWidget {
  const _ReceiptBadge({required this.receipt, required this.contentVersion});

  final AnnouncementReceipt? receipt;
  final int contentVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = receipt?.status;
    final isEdited =
        receipt != null && receipt!.receiptVersion < contentVersion;

    final (label, icon, backgroundColor, foregroundColor, borderColor) =
        isEdited
            ? (
              'Editado',
              Icons.edit_notifications_outlined,
              Colors.orange.shade700,
              Colors.white,
              Colors.transparent,
            )
            : switch (status) {
              null || AnnouncementReceiptStatus.delivered => (
                'Nuevo',
                Icons.fiber_new_outlined,
                theme.colorScheme.primaryContainer,
                theme.colorScheme.onPrimaryContainer,
                Colors.transparent,
              ),
              AnnouncementReceiptStatus.seen => (
                'Visto',
                Icons.visibility_outlined,
                theme.colorScheme.secondaryContainer,
                theme.colorScheme.onSecondaryContainer,
                Colors.transparent,
              ),
              AnnouncementReceiptStatus.read => (
                'Leído',
                Icons.done_all,
                theme.colorScheme.surface,
                Colors.blue.shade700,
                Colors.blue.shade200,
              ),
              AnnouncementReceiptStatus.confirmed => (
                'Confirmado',
                Icons.verified_outlined,
                Colors.green.shade700,
                Colors.white,
                Colors.transparent,
              ),
            };

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
            Icon(icon, size: 16, color: foregroundColor),
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

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final AnnouncementPriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (
      label,
      backgroundColor,
      foregroundColor,
      borderColor,
    ) = switch (priority) {
      AnnouncementPriority.low => (
        'Baja',
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outlineVariant,
      ),
      AnnouncementPriority.normal => (
        'Normal',
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outlineVariant,
      ),
      AnnouncementPriority.high => (
        'Importante',
        Colors.amber.shade900,
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
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyAnnouncementsView extends StatelessWidget {
  const _EmptyAnnouncementsView({required this.filter});

  final _PublicationFeedFilter filter;

  @override
  Widget build(BuildContext context) {
    final (message, icon) = switch (filter) {
      _PublicationFeedFilter.all => (
        'No hay noticias ni comunicados disponibles para tu perfil.',
        Icons.article_outlined,
      ),
      _PublicationFeedFilter.news => (
        'No hay noticias publicadas en este momento.',
        Icons.newspaper_outlined,
      ),
      _PublicationFeedFilter.announcements => (
        'No hay comunicados disponibles para tu perfil.',
        Icons.campaign_outlined,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<AnnouncementBloc>().add(const AnnouncementsStarted());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xlg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 56),
                      const SizedBox(height: AppSpacing.md),
                      Text(message, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InstitutionalProfileRequiredView extends StatelessWidget {
  const _InstitutionalProfileRequiredView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 56),
            SizedBox(height: AppSpacing.md),
            Text(
              'Inicia sesión para consultar noticias y comunicados institucionales.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
