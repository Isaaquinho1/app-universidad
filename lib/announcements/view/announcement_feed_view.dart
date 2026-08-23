import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/feed/widgets/widgets.dart';

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
  int _heroRefreshToken = 0;

  Future<void> _refreshFeed() async {
    context.read<AnnouncementBloc>().add(const AnnouncementsStarted());

    setState(() {
      _heroRefreshToken++;
    });

    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Widget _buildFeedShell({
    required List<Widget> contentSlivers,
    required bool showFilters,
  }) {
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: CampusContextHero(refreshToken: _heroRefreshToken),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xlg + AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Publicaciones',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (showFilters)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _PublicationFilterBar(
                  selectedFilter: _filter,
                  onChanged: (filter) {
                    setState(() {
                      _filter = filter;
                    });
                  },
                ),
              ),
            ),
          ...contentSlivers,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnnouncementBloc, AnnouncementState>(
      builder: (context, state) {
        switch (state.status) {
          case AnnouncementsStatus.initial:
          case AnnouncementsStatus.loading:
            return _buildFeedShell(
              showFilters: false,
              contentSlivers: const [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );

          case AnnouncementsStatus.failure:
            return _buildFeedShell(
              showFilters: false,
              contentSlivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: FailureScreen(
                    title: 'Error de carga',
                    description:
                        'No se pudieron cargar las publicaciones institucionales.',
                    icon: Icons.campaign_outlined,
                    buttonText: 'Reintentar',
                    onButtonPressed: () {
                      context.read<AnnouncementBloc>().add(
                        const AnnouncementsStarted(),
                      );

                      setState(() {
                        _heroRefreshToken++;
                      });
                    },
                  ),
                ),
              ],
            );

          case AnnouncementsStatus.populated:
            final publications = state.announcements
                .where(_filter.accepts)
                .toList(growable: false);

            return _buildFeedShell(
              showFilters: true,
              contentSlivers: [
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

                        return _AnimatedPublicationCard(
                          key: ValueKey('publication-${announcement.id}'),
                          animationToken: _filter,
                          child: AnnouncementCard(
                            announcement: announcement,
                            receipt:
                                state.receiptsByAnnouncementId[announcement.id],
                            assets:
                                state.assetsByAnnouncementId[announcement.id] ??
                                const [],
                          ),
                        );
                      },
                      separatorBuilder:
                          (_, _) => const SizedBox(height: AppSpacing.lg),
                    ),
                  ),
              ],
            );
        }
      },
    );
  }
}

class _AnimatedPublicationCard extends StatefulWidget {
  const _AnimatedPublicationCard({
    required this.animationToken,
    required this.child,
    super.key,
  });

  final Object animationToken;
  final Widget child;

  @override
  State<_AnimatedPublicationCard> createState() =>
      _AnimatedPublicationCardState();
}

class _AnimatedPublicationCardState extends State<_AnimatedPublicationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacity = animation;
    _offset = Tween<double>(begin: 10, end: 0).animate(animation);

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedPublicationCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animationToken != widget.animationToken) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _offset.value),
            child: child,
          ),
        );
      },
    );
  }
}

class _PublicationFilterBar extends StatelessWidget {
  const _PublicationFilterBar({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _PublicationFeedFilter selectedFilter;
  final ValueChanged<_PublicationFeedFilter> onChanged;

  Alignment get _selectedAlignment {
    return switch (selectedFilter) {
      _PublicationFeedFilter.all => Alignment.centerLeft,
      _PublicationFeedFilter.news => Alignment.center,
      _PublicationFeedFilter.announcements => Alignment.centerRight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 3;

          return Stack(
            children: [
              AnimatedAlign(
                alignment: _selectedAlignment,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: itemWidth,
                  height: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.surface.withValues(alpha: 0.94),
                            colorScheme.surface.withValues(alpha: 0.82),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.045),
                            blurRadius: 7,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: _PublicationFeedFilter.values
                    .map((filter) {
                      final isSelected = filter == selectedFilter;

                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (!isSelected) {
                                onChanged(filter);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            splashColor: colorScheme.primary.withValues(
                              alpha: 0.04,
                            ),
                            highlightColor: colorScheme.primary.withValues(
                              alpha: 0.025,
                            ),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                style: (theme.textTheme.labelLarge ??
                                        const TextStyle())
                                    .copyWith(
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                      color:
                                          isSelected
                                              ? colorScheme.onSurface
                                              : colorScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.82),
                                    ),
                                child: Text(filter.label),
                              ),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          );
        },
      ),
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

    final isFeatured = announcement.isCurrentlyFeatured;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: isFeatured ? 1.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      surfaceTintColor: Colors.transparent,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color:
              isFeatured
                  ? Colors.amber.shade400.withValues(alpha: 0.40)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _PublicationTypeBadge(announcement: announcement),
                            if (announcement.isNews &&
                                announcement.newsCategory?.trim().isNotEmpty ==
                                    true)
                              _NewsCategoryBadge(
                                category: announcement.newsCategory!.trim(),
                              ),
                          ],
                        ),
                      ),
                      if (announcement.isCurrentlyFeatured) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const _FeaturedBadge(),
                      ],
                    ],
                  ),
                  if (announcement.isAnnouncement) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PriorityBadge(priority: announcement.priority),
                        _ReceiptBadge(
                          receipt: receipt,
                          contentVersion: announcement.contentVersion,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    announcement.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle_outlined,
                        size: 17,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          announcement.authorName ?? 'TecNM Campus Tlalpan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_attachmentCount > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.attach_file,
                          size: 17,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$_attachmentCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
