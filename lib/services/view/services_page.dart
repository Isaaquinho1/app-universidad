import 'package:flutter/material.dart';
import 'package:conecta_itt/l10n/l10n.dart';
import 'package:conecta_itt/services/services.dart';
import 'package:app_ui/app_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import 'dart:async';
import 'package:conecta_itt/app/app.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    final title =
        profile?.canManageAnnouncements ?? false
            ? 'Administración'
            : profile?.isTeacher ?? false
            ? 'Docencia'
            : context.l10n.services;

    return Scaffold(
      appBar: AppBar(elevation: 0, title: Text(title)),
      body: const ServicesView(),
    );
  }
}

class ServicesView extends StatefulWidget {
  const ServicesView({super.key});

  @override
  State<ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<ServicesView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  late final PageController _bannersPageController;
  Timer? _autoScrollTimer;
  Timer? _resumeScrollTimer;
  bool _isUserInteracting = false;
  bool _isScreenInFocus = true;

  final List<String> _categories = [
    "Campus",
    "Servicios digitales · Próximamente",
  ];
  int _selectedIndex = 0;
  int _currentBannerIndex = 0;

  late List<ImportantServiceModel> _importantServices;
  late List<CommunityModel> _communities;
  late List<BannerModel> _banners;
  late List<ServiceTileModel> _mainServices;
  late List<HorizontalServiceModel> _studentLifeServices;
  late List<WideServiceModel> _usefulServices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pageController = PageController();
    _bannersPageController = PageController();
    _bannersPageController.addListener(_syncBannerIndex);
    if (_isScreenInFocus) {
      _startAutoScroll();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always re-fetch from config when dependencies change
    final important = ServicesConfig.getImportantServices(context);
    final communities = ServicesConfig.getCommunities(context);
    final banners = ServicesConfig.getBanners(context);
    final mainServices = ServicesConfig.getMainServices(context);
    final studentLife = ServicesConfig.getStudentLifeServices(context);
    final useful = ServicesConfig.getUsefulServices(context);

    // Assign without using final to avoid LateInitializationError on rebuilds
    _importantServices = important;
    _communities = communities;
    _banners = banners;
    _mainServices = mainServices;
    _studentLifeServices = studentLife;
    _usefulServices = useful;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _isScreenInFocus = true;
          });
          _startAutoScroll();
        });
      }
    } else {
      setState(() {
        _isScreenInFocus = false;
      });
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _isUserInteracting || !_isScreenInFocus) return;

      if (_banners.isEmpty) return;

      if (!_bannersPageController.hasClients) return;

      _currentBannerIndex = (_currentBannerIndex + 1) % _banners.length;

      try {
        _bannersPageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        // Controller might be disposed or not attached during the animation
        // Just ignore the error and wait for the next timer tick
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _pauseAutoScroll() {
    _isUserInteracting = true;
    _resumeScrollTimer?.cancel();
    _resumeScrollTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isUserInteracting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannersPageController.removeListener(_syncBannerIndex);
    _bannersPageController.dispose();
    _pageController.dispose();
    _stopAutoScroll();
    _resumeScrollTimer?.cancel();
    super.dispose();
  }

  void _onCategorySelected(int index) {
    if (index == 1) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Servicios digitales estará disponible próximamente.',
            ),
          ),
        );
      return;
    }

    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    if (!_pageController.hasClients) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutQuint,
    );
  }

  void _syncBannerIndex() {
    if (_bannersPageController.hasClients &&
        _bannersPageController.page != null) {
      if (_banners.isNotEmpty) {
        final currentPage =
            _bannersPageController.page!.round() % _banners.length;
        if (_currentBannerIndex != currentPage) {
          setState(() {
            _currentBannerIndex = currentPage;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile?.canManageAnnouncements ?? false) {
      return _buildAdministrationView();
    }

    if (profile?.isTeacher ?? false) {
      return _buildTeacherView();
    }

    return _buildStudentServicesView();
  }

  Widget _buildStudentServicesView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: ConectaSegmentedSelector<int>(
            selectedValue: _selectedIndex,
            onChanged: _onCategorySelected,
            items: [
              for (var index = 0; index < _categories.length; index++)
                ConectaSegmentedItem(value: index, label: _categories[index]),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: [_buildMainTab(), _buildDigitalUniversityTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildAdministrationView() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Herramientas administrativas',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Gestiona publicaciones y procesos institucionales '
          'desde un solo lugar.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xlg),
        _AdministrativeServiceTile(
          icon: Icons.campaign_outlined,
          title: 'Gestión de publicaciones',
          description: 'Crea, edita y revisa publicaciones institucionales.',
          onTap: () => context.go('/services/announcement-management'),
        ),
        const SizedBox(height: AppSpacing.md),
        _AdministrativeServiceTile(
          icon: Icons.fact_check_outlined,
          title: 'Revisión de fotografías',
          description:
              'Revisa fotografías institucionales enviadas '
              'por estudiantes.',
          onTap: () => context.go('/services/photo-review'),
        ),
        const SizedBox(height: AppSpacing.md),
        _AdministrativeServiceTile(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Validar identificación',
          description:
              'Valida identificaciones digitales mediante '
              'su código QR.',
          onTap: () => context.go('/services/id-validator'),
        ),
      ],
    );
  }

  Widget _buildTeacherView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xlg + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          'Herramientas docentes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Este espacio reunirá las herramientas académicas '
          'disponibles para docentes.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xlg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xlg),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.school_outlined,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Espacio docente en preparación',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Aquí podremos incorporar horario docente, '
                'grupos, materias y otras herramientas cuando '
                'estén disponibles en Conecta ITT.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainTab() {
    final colors = Theme.of(context).extension<AppColors>()!;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlg),
          child: const SectionHeader(title: "Importantes"),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 170,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: _importantServices.length,
            itemBuilder: (context, index) {
              final service = _importantServices[index];

              return ServiceCard(
                title: service.title,
                description: service.description,
                onTap: () => ServiceUtils.navigateToService(context, service),
                icon: ServiceIcon(
                  color: service.color,
                  iconColor: Theme.of(context).extension<AppColors>()!.active,
                  icon: service.iconData,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xlg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlg),
          child: const SectionHeader(title: "Canales oficiales"),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _communities.length,
            itemBuilder: (context, index) {
              final community = _communities[index];
              return Column(
                children: [
                  CommunityCard(
                    title: community.title,
                    url: community.url,
                    logo: CircleAvatar(
                      backgroundColor: colors.background03,
                      child: Icon(Icons.school_rounded, color: colors.active),
                    ),
                    launchMode: LaunchMode.externalApplication,
                    description: community.description,
                  ),
                  if (index < _communities.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xlg),
      ],
    );
  }

  Widget _buildDigitalUniversityTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xlg,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 202,
              child: GestureDetector(
                onTap: _pauseAutoScroll,
                onPanDown: (_) => _pauseAutoScroll(),
                child: PageView.builder(
                  controller: _bannersPageController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _banners.length,
                  itemBuilder: (context, index) {
                    final banner = _banners[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: VerticalBanner(
                        title: banner.title,
                        description: banner.description ?? '',
                        iconData: banner.iconData,
                        color: banner.color,
                        action: banner.action,
                        onTap:
                            () =>
                                ServiceUtils.navigateToService(context, banner),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _banners.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        index == _currentBannerIndex
                            ? Theme.of(context).extension<AppColors>()!.primary
                            : Theme.of(context)
                                .extension<AppColors>()!
                                .deactive
                                .withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xlg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlg),
          child: const SectionHeader(title: 'Servicios principales'),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: LayoutGrid(
            autoPlacement: AutoPlacement.rowDense,
            columnSizes: List.filled(4, 1.fr),
            rowSizes: List.generate(
              (_mainServices.length / 4).ceil(),
              (_) => auto,
            ),
            columnGap: AppSpacing.md,
            rowGap: AppSpacing.sm,
            children:
                _mainServices
                    .map(
                      (service) => ServiceTile(
                        title: service.title,
                        iconData: service.iconData,
                        color: service.color,
                        onTap:
                            () => ServiceUtils.navigateToService(
                              context,
                              service,
                            ),
                      ),
                    )
                    .toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xlg),
              child: const SectionHeader(title: 'Vida estudiantil'),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildHorizontalCardsList(),
          ],
        ),
        const SizedBox(height: AppSpacing.xlg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Útil'),
              const SizedBox(height: AppSpacing.lg),
              _buildWideCardsList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalCardsList() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlg),
        itemCount: _studentLifeServices.length,
        itemBuilder: (context, index) {
          final service = _studentLifeServices[index];
          return HorizontalServiceCard(
            title: service.title,
            description: service.description ?? '',
            iconData: service.iconData,
            color: service.color,
            onTap: () => ServiceUtils.navigateToService(context, service),
          );
        },
      ),
    );
  }

  Widget _buildWideCardsList() {
    return Column(
      children:
          _usefulServices.asMap().entries.map((entry) {
            final index = entry.key;
            final service = entry.value;

            return Column(
              children: [
                WideServiceCard(
                  title: service.title,
                  description: service.description ?? '',
                  iconData: service.iconData,
                  color: service.color,
                  onTap: () => ServiceUtils.navigateToService(context, service),
                ),
                if (index < _usefulServices.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            );
          }).toList(),
    );
  }
}

class _AdministrativeServiceTile extends StatelessWidget {
  const _AdministrativeServiceTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colorScheme.onSurface),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
