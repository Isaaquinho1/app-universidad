import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rtu_mirea_app/announcements/announcements.dart';
import 'package:rtu_mirea_app/app/app.dart';

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
            profile: profile,
          )..add(const AnnouncementsStarted()),
      child: AnnouncementFeedView(scrollController: scrollController),
    );
  }
}

/// Displays announcements already filtered for the current student.
class AnnouncementFeedView extends StatelessWidget {
  const AnnouncementFeedView({this.scrollController, super.key});

  final ScrollController? scrollController;

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
              description: 'No se pudieron cargar los comunicados.',
              icon: Icons.campaign_outlined,
              buttonText: 'Reintentar',
              onButtonPressed: () {
                context.read<AnnouncementBloc>().add(
                  const AnnouncementsStarted(),
                );
              },
            );

          case AnnouncementsStatus.populated:
            if (state.announcements.isEmpty) {
              return const _EmptyAnnouncementsView();
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AnnouncementBloc>().add(
                  const AnnouncementsStarted(),
                );

                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    sliver: SliverList.separated(
                      itemCount: state.announcements.length,
                      itemBuilder: (context, index) {
                        return AnnouncementCard(
                          announcement: state.announcements[index],
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
  const AnnouncementCard({required this.announcement, super.key});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description =
        announcement.summary?.trim().isNotEmpty ?? false
            ? announcement.summary!
            : announcement.body;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // La navegación al detalle se implementará en el siguiente subbloque.
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      announcement.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PriorityBadge(priority: announcement.priority),
                ],
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
                  if (announcement.attachmentUrls.isNotEmpty) ...[
                    const Icon(Icons.attach_file, size: 18),
                    Text(
                      '${announcement.attachmentUrls.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
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
    final label = switch (priority) {
      AnnouncementPriority.low => 'Baja',
      AnnouncementPriority.normal => 'Normal',
      AnnouncementPriority.high => 'Importante',
      AnnouncementPriority.urgent => 'Urgente',
    };

    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class _EmptyAnnouncementsView extends StatelessWidget {
  const _EmptyAnnouncementsView();

  @override
  Widget build(BuildContext context) {
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
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xlg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_outlined, size: 56),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'No hay comunicados disponibles para tu perfil.',
                        textAlign: TextAlign.center,
                      ),
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
              'Inicia sesión para consultar los comunicados dirigidos a tu perfil.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
