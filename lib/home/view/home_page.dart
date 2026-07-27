import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/home/cubit/home_cubit.dart';

/// Resolves the first destination according to onboarding and auth state.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit()..checkOnboarding(),
      child: BlocConsumer<HomeCubit, HomeState>(
        builder: (context, state) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
        listener: (context, state) {
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
        },
      ),
    );
  }
}
