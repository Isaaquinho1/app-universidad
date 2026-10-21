import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
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
      return const _InstitutionalProfileLoadingView();
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
  _PublicationFeedFilter _previousFilter = _PublicationFeedFilter.all;
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
          if (showFilters)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _PublicationFilterBar(
                  selectedFilter: _filter,
                  onChanged: (filter) {
                    setState(() {
                      _previousFilter = _filter;
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
                SliverToBoxAdapter(child: _PublicationLoadingState()),
              ],
            );

          case AnnouncementsStatus.failure:
            return _buildFeedShell(
              showFilters: false,
              contentSlivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _PublicationErrorState(
                    onRetry: () {
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
                    child: _EmptyAnnouncementsView(
                      filter: _filter,
                      onShowAll:
                          _filter == _PublicationFeedFilter.all
                              ? null
                              : () {
                                setState(() {
                                  _previousFilter = _filter;
                                  _filter = _PublicationFeedFilter.all;
                                });
                              },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: publications.length,
                      itemBuilder: (context, index) {
                        final announcement = publications[index];

                        return _AnimatedPublicationCard(
                          key: ValueKey('publication-${announcement.id}'),
                          animationToken: _filter,
                          horizontalDirection: _filter.index.compareTo(
                            _previousFilter.index,
                          ),
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                    ),
                  ),
              ],
            );
        }
      },
    );
  }
}

class _InstitutionalProfileLoadingView extends StatelessWidget {
  const _InstitutionalProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Preparando tu feed',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Estamos cargando la información de tu perfil.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicationErrorState extends StatelessWidget {
  const _PublicationErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xlg,
          AppSpacing.xlg,
          AppSpacing.xlg,
          AppSpacing.xlg * 2,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_outlined,
                  size: 25,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No pudimos actualizar el feed',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Revisa tu conexión e inténtalo de nuevo. '
                'Tus publicaciones volverán a aparecer cuando podamos conectarnos.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Reintentar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicationLoadingState extends StatelessWidget {
  const _PublicationLoadingState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xlg,
      ),
      child: Shimmer.fromColors(
        baseColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        highlightColor: colorScheme.surface.withValues(alpha: 0.96),
        period: const Duration(milliseconds: 1350),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SkeletonBox(height: 46, borderRadius: 16),
            SizedBox(height: AppSpacing.lg),
            _PublicationCardSkeleton(),
            SizedBox(height: AppSpacing.lg),
            _PublicationCardSkeleton(imageHeight: 150),
          ],
        ),
      ),
    );
  }
}

class _PublicationCardSkeleton extends StatelessWidget {
  const _PublicationCardSkeleton({this.imageHeight = 185});

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SkeletonBox(height: imageHeight, borderRadius: 0),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 92, height: 16, borderRadius: 8),
                SizedBox(height: AppSpacing.md),
                _SkeletonBox(height: 22, borderRadius: 8),
                SizedBox(height: AppSpacing.sm),
                _SkeletonBox(width: 240, height: 16, borderRadius: 8),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: _SkeletonBox(height: 12, borderRadius: 6)),
                    SizedBox(width: AppSpacing.xlg),
                    _SkeletonBox(width: 74, height: 12, borderRadius: 6),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.borderRadius,
    this.width,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _AnimatedPublicationCard extends StatefulWidget {
  const _AnimatedPublicationCard({
    required this.animationToken,
    required this.horizontalDirection,
    required this.child,
    super.key,
  });

  final Object animationToken;
  final int horizontalDirection;
  final Widget child;

  @override
  State<_AnimatedPublicationCard> createState() =>
      _AnimatedPublicationCardState();
}

class _AnimatedPublicationCardState extends State<_AnimatedPublicationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _horizontalOffset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _configureAnimation();
    _controller.forward();
  }

  void _configureAnimation() {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    final direction = widget.horizontalDirection.sign;

    _opacity = Tween<double>(begin: 0.72, end: 1).animate(curved);

    _horizontalOffset = Tween<double>(
      begin: 24.0 * direction,
      end: 0,
    ).animate(curved);
  }

  @override
  void didUpdateWidget(covariant _AnimatedPublicationCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animationToken != widget.animationToken) {
      _configureAnimation();
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
            offset: Offset(_horizontalOffset.value, 0),
            child: child,
          ),
        );
      },
    );
  }
}

/// REDISENO MINIMALISTA 13.2-13.3
class _PublicationFilterBar extends StatelessWidget {
  const _PublicationFilterBar({
    required this.selectedFilter,
    required this.onChanged,
  });
  final _PublicationFeedFilter selectedFilter;
  final ValueChanged<_PublicationFeedFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, dimensions) {
        final compact = dimensions.maxWidth < 355;
        return Row(
          children: [
            for (final filter in _PublicationFeedFilter.values) ...[
              if (filter != _PublicationFeedFilter.all)
                const SizedBox(width: 7),
              Expanded(
                child: Material(
                  color:
                      filter == selectedFilter
                          ? const Color(0xFF192B50)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap:
                        filter == selectedFilter
                            ? null
                            : () => onChanged(filter),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            switch (filter) {
                              _PublicationFeedFilter.all =>
                                Icons.grid_view_rounded,
                              _PublicationFeedFilter.news =>
                                Icons.article_outlined,
                              _PublicationFeedFilter.announcements =>
                                Icons.campaign_outlined,
                            },
                            size: compact ? 15 : 16,
                            color:
                                filter == selectedFilter
                                    ? Colors.white
                                    : const Color(0xFF27334E),
                          ),
                          SizedBox(width: compact ? 4 : 6),
                          Flexible(
                            child: Text(
                              filter.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 12 : 13,
                                fontWeight:
                                    filter == selectedFilter
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                color:
                                    filter == selectedFilter
                                        ? Colors.white
                                        : const Color(0xFF27334E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// BLOQUE_13_5D
// BLOQUE_13_5E
// BLOQUE_13_8B
// BLOQUE_13_8C
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

  String? get publicationDateLabel {
    final date = announcement.publishedAt ?? announcement.createdAt;
    if (date.year < 2000) return null;

    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]}. ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = _coverAsset;

    final isFeatured = announcement.isCurrentlyFeatured;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      surfaceTintColor: Colors.transparent,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: const Color(0xFFE9EDF3), width: 1),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 350;
            final thumbnailSize = compact ? 117.0 : 130.0;
            // BLOQUE_13_10G
            final thumbnailHeight = thumbnailSize * 1.10;
            // BLOQUE_13_10F
            // BLOQUE_13_10I
            final hasVisual = cover != null || announcement.isAnnouncement;

            final previewText =
                announcement.summary?.trim().isNotEmpty == true
                    ? announcement.summary!.trim()
                    : announcement.body.trim();

            final thumbnailWidth = compact ? 117.0 : 130.0;

            // BLOQUE_13_10J3_COMPACTO
            // BLOQUE_13_10L_APLICADO
            // BLOQUE_13_10J7
            // BLOQUE_13_10J6_CORREGIDO
            // BLOQUE_13_10J5_APLICADO
            // Diseño exclusivo para comunicados sin portada real.
            if (cover == null && announcement.isAnnouncement) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: SizedBox(
                  height: compact ? 114 : 108,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: compact ? 68 : 74,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          child: const ColoredBox(
                            color: Color(0xFFEAF4EF),
                            child: Center(
                              child: Icon(
                                Icons.fact_check_outlined,
                                size: 32,
                                color: Color(0xFF379B71),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _PublicationTypeBadge(
                                    announcement: announcement,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: FittedBox(
                                        alignment: Alignment.centerRight,
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _PriorityBadge(
                                              priority: announcement.priority,
                                            ),
                                            const SizedBox(width: 5),
                                            _ReceiptBadge(
                                              receipt: receipt,
                                              contentVersion:
                                                  announcement.contentVersion,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                announcement.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 13.8,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              if (previewText.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.8,
                                    height: 1.15,
                                    color: Color(0xFF586174),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_circle_outlined,
                                    size: 11,
                                    color: Color(0xFF586174),
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      announcement.authorName ??
                                          'TecNM Campus Tlalpan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFF586174),
                                      ),
                                    ),
                                  ),
                                  if (_attachmentCount > 0)
                                    const Icon(
                                      Icons.attach_file,
                                      size: 10,
                                      color: Color(0xFF586174),
                                    ),
                                  if (publicationDateLabel != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      publicationDateLabel!,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFF788397),
                                      ),
                                    ),
                                  ],
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 15,
                                    color: Color(0xFF192B50),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: IntrinsicHeight(
                child: Row(
                  // BLOQUE_13_10K
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasVisual)
                      SizedBox(
                        width: thumbnailWidth,
                        child:
                            cover != null
                                ? ClipRRect(
                                  // BLOQUE_13_10J1
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  child: SizedBox(
                                    height: thumbnailHeight,
                                    child: PublicationAssetImage(
                                      asset: cover,
                                      width: thumbnailWidth,
                                      height: thumbnailHeight,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                                : const ColoredBox(
                                  color: Color(0xFFEAF4EF),
                                  child: Center(
                                    child: Icon(
                                      Icons.fact_check_outlined,
                                      size: 46,
                                      color: Color(0xFF379B71),
                                    ),
                                  ),
                                ),
                      ),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // BLOQUE_13_10J2
                          minHeight: cover != null ? thumbnailHeight : 0,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            hasVisual ? 12 : 14,
                            10,
                            11,
                            10,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (announcement.isAnnouncement)
                                    Row(
                                      children: [
                                        _PublicationTypeBadge(
                                          announcement: announcement,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                              alignment: Alignment.centerRight,
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _PriorityBadge(
                                                    priority:
                                                        announcement.priority,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  _ReceiptBadge(
                                                    receipt: receipt,
                                                    contentVersion:
                                                        announcement
                                                            .contentVersion,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        _PublicationTypeBadge(
                                          announcement: announcement,
                                        ),
                                        if (isFeatured) ...[
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: const _FeaturedBadge(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    announcement.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: compact ? 12.8 : 13.8,
                                          height: 1.15,
                                          letterSpacing: -0.25,
                                          color: const Color(0xFF111827),
                                        ),
                                  ),
                                  if (announcement.isNews &&
                                      announcement.newsCategory
                                              ?.trim()
                                              .isNotEmpty ==
                                          true) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.sell_outlined,
                                          size: 12,
                                          color: Color(0xFF586174),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            announcement.newsCategory!.trim(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFF586174),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (previewText.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      previewText,
                                      maxLines: cover != null ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 9.8,
                                        height: 1.25,
                                        color: Color(0xFF586174),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.account_circle_outlined,
                                      size: 12,
                                      color: Color(0xFF586174),
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        announcement.authorName ??
                                            'TecNM Campus Tlalpan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 8.6,
                                          color: Color(0xFF586174),
                                        ),
                                      ),
                                    ),
                                    if (_attachmentCount > 0)
                                      const Icon(
                                        Icons.attach_file,
                                        size: 11,
                                        color: Color(0xFF586174),
                                      ),
                                    if (publicationDateLabel != null) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        publicationDateLabel!,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 8.6,
                                          color: Color(0xFF788397),
                                        ),
                                      ),
                                    ],
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: Color(0xFF192B50),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontSize: 9.5,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
}

class _EmptyAnnouncementsView extends StatelessWidget {
  const _EmptyAnnouncementsView({required this.filter, this.onShowAll});

  final _PublicationFeedFilter filter;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (title, description, icon) = switch (filter) {
      _PublicationFeedFilter.all => (
        'Todo al día',
        'No hay noticias ni comunicados nuevos para tu perfil.',
        Icons.check_rounded,
      ),
      _PublicationFeedFilter.news => (
        'Sin noticias por ahora',
        'Cuando haya nuevas noticias institucionales, aparecerán aquí.',
        Icons.newspaper_outlined,
      ),
      _PublicationFeedFilter.announcements => (
        'Sin comunicados por ahora',
        'No hay comunicados dirigidos a tu perfil en este momento.',
        Icons.campaign_outlined,
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xlg,
          AppSpacing.xlg,
          AppSpacing.xlg,
          AppSpacing.xlg * 2,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.55,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 25,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (onShowAll != null) ...[
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: onShowAll,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  child: const Text(
                    'Ver todas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
