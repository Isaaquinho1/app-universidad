import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rtu_mirea_app/login/login.dart';
import 'package:user_repository/user_repository.dart';

/// Page used to create a TecNM institutional account.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  /// Creates the registration route.
  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const RegisterPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => RegisterBloc(userRepository: context.read<UserRepository>()),
      child: Scaffold(
        appBar: AppBar(),
        backgroundColor: Theme.of(context).extension<AppColors>()!.background01,
        body: const RegisterForm(),
      ),
    );
  }
}
