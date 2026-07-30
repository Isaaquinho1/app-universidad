import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/home/cubit/home_cubit.dart';

/// Displays the institutional startup screen and resolves the initial route.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _visibleDuration = Duration(milliseconds: 700);

  final Completer<void> _splashVisible = Completer<void>();
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      unawaited(_completeVisiblePeriod());
    });
  }

  Future<void> _completeVisiblePeriod() async {
    await Future<void>.delayed(_visibleDuration);

    if (!_splashVisible.isCompleted) {
      _splashVisible.complete();
    }
  }

  Future<void> _resolveNavigation(BuildContext context, HomeState state) async {
    if (_navigationScheduled) {
      return;
    }

    _navigationScheduled = true;

    await _splashVisible.future;

    if (!context.mounted) {
      return;
    }

    if (state is AppOnboarding) {
      context.replace('/onboarding');
      return;
    }

    final appStatus = context.read<AppBloc>().state.status;

    if (appStatus.isLoggedIn) {
      context.go('/feed');
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..checkOnboarding(),
      child: BlocListener<HomeCubit, HomeState>(
        listener: _resolveNavigation,
        child: const _InstitutionalSplash(),
      ),
    );
  }
}

class _InstitutionalSplash extends StatelessWidget {
  const _InstitutionalSplash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoWidth = (screenWidth * 0.17).clamp(58.0, 82.0);

    return Scaffold(
      backgroundColor: const Color(0xFF003B5C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SplashBackground(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/branding/conecta_itt_logo_clean.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Conecta ITT',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'TecNM Campus Tlalpan',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF003B5C),
      child: Stack(
        children: const [
          Positioned(
            top: -100,
            right: -85,
            child: _DecorativeCircle(diameter: 275, opacity: 0.055),
          ),
          Positioned(
            bottom: -135,
            left: -110,
            child: _DecorativeCircle(diameter: 335, opacity: 0.045),
          ),
        ],
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.diameter, required this.opacity});

  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
