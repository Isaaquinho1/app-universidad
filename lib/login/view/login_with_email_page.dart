import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/login/login.dart';
import 'package:user_repository/user_repository.dart';

class LoginWithEmailPage extends StatelessWidget {
  const LoginWithEmailPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const LoginWithEmailPage());
  }

  @override
  Widget build(BuildContext context) {
    final biometricLoginService = BiometricLoginService();

    return BlocProvider(
      create:
          (_) => LoginBloc(
            userRepository: context.read<UserRepository>(),
            biometricLoginService: biometricLoginService,
          )..add(const LoginBiometricAvailabilityRequested()),
      child: const Scaffold(
        resizeToAvoidBottomInset: true,
        body: LoginWithEmailForm(),
      ),
    );
  }
}
