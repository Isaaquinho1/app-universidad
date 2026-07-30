import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/home/cubit/home_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';

/// Resolves the initial route while the native splash remains visible.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _navigationScheduled = false;

  void _resolveNavigation(BuildContext context, HomeState state) {
    if (_navigationScheduled) {
      return;
    }

    _navigationScheduled = true;

    if (state is AppOnboarding) {
      context.replace('/onboarding');
      _removeNativeSplashAfterNavigation();
      return;
    }

    final appStatus = context.read<AppBloc>().state.status;

    if (appStatus.isLoggedIn) {
      context.go('/feed');
    } else {
      context.go('/welcome');
    }

    _removeNativeSplashAfterNavigation();
  }

  void _removeNativeSplashAfterNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..checkOnboarding(),
      child: BlocListener<HomeCubit, HomeState>(
        listener: _resolveNavigation,
        child: const ColoredBox(
          color: Color(0xFF003B5C),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
