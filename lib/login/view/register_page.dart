import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:conecta_itt/login/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user_repository/user_repository.dart';

/// Page used to create a TecNM institutional account.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const RegisterPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) => RegisterBloc(
            userRepository: context.read<UserRepository>(),
            academicCatalogRepository: AcademicCatalogRepository(
              supabaseClient: Supabase.instance.client,
            ),
          ),
      child: const Scaffold(
        resizeToAvoidBottomInset: true,
        body: RegisterForm(),
      ),
    );
  }
}
