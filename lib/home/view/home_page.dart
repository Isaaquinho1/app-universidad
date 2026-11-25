import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/home/cubit/home_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/splash/widgets/institutional_startup_splash.dart';
import 'package:go_router/go_router.dart';

/// Resolves onboarding while preserving the institutional first Flutter frame.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _navigationScheduled = false;

  void _resolveNavigation(BuildContext context, HomeState state) {
    if (_navigationScheduled || state is AppInitial) {
      return;
    }

    _navigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // A push or deep link may already have selected its destination.
      final router = GoRouter.of(context);
      if (router.routeInformationProvider.value.uri.path != '/home') return;

      if (state is AppOnboarding) {
        context.replace('/onboarding');
      } else {
        final appStatus = context.read<AppBloc>().state.status;
        context.go(appStatus.isLoggedIn ? '/feed' : '/welcome');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..checkOnboarding(),
      child: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          _resolveNavigation(context, state);

          return const InstitutionalStartupSplash();
        },
      ),
    );
  }
}
