import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:conecta_itt/login/login.dart';

class LoginWithEmailForm extends StatelessWidget {
  const LoginWithEmailForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LoginBloc, LoginState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.status.isSuccess) {
          Navigator.of(context).pop();
          return;
        }

        if (state.status.isFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage ?? 'No fue posible iniciar sesión.',
                ),
              ),
            );
        }
      },
      child: const SafeArea(
        child: AutofillGroup(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xlg,
                    AppSpacing.lg,
                    AppSpacing.xlg,
                    AppSpacing.xxlg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(),
                      SizedBox(height: AppSpacing.xxxlg),
                      _EmailInput(),
                      SizedBox(height: AppSpacing.lg),
                      _PasswordInput(),
                      SizedBox(height: AppSpacing.sm),
                      _ForgotPasswordButton(),
                      Spacer(),
                      _LoginButton(),
                      SizedBox(height: AppSpacing.md),
                      _RegisterButton(),
                      SizedBox(height: AppSpacing.lg),
                      _InstitutionalAccessNotice(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Iniciar sesión',
          key: const Key('loginWithEmailForm_header_title'),
          style: AppTextStyle.h4.copyWith(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Accede con tu correo institucional del TecNM Campus Tlalpan.',
          style: AppTextStyle.body.copyWith(
            color: theme.extension<AppColors>()!.deactive,
          ),
        ),
      ],
    );
  }
}

class _EmailInput extends StatefulWidget {
  const _EmailInput();

  @override
  State<_EmailInput> createState() => _EmailInputState();
}

class _EmailInputState extends State<_EmailInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final email = context.select((LoginBloc bloc) => bloc.state.email);

    return LabelledInput(
      key: const Key('loginWithEmailForm_emailInput_textField'),
      controller: _controller,
      label: 'Correo institucional',
      placeholder: 'correo@tlalpan.tecnm.mx',
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      onChanged:
          (value) => context.read<LoginBloc>().add(LoginEmailChanged(value)),
      errorText:
          email.isPure || email.isValid
              ? null
              : 'Ingresa un correo institucional válido.',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PasswordInput extends StatefulWidget {
  const _PasswordInput();

  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final password = context.select((LoginBloc bloc) => bloc.state.password);

    return LabelledInput(
      key: const Key('loginWithEmailForm_passwordInput_textField'),
      controller: _controller,
      label: 'Contraseña',
      placeholder: 'Mínimo 8 caracteres',
      obscureText: true,
      showPasswordToggle: true,
      autofillHints: const [AutofillHints.password],
      onChanged:
          (value) => context.read<LoginBloc>().add(LoginPasswordChanged(value)),
      errorText:
          password.isPure || password.isValid
              ? null
              : 'La contraseña debe tener al menos 8 caracteres.',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _ForgotPasswordButton extends StatelessWidget {
  const _ForgotPasswordButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        key: const Key('loginWithEmailForm_forgotPasswordButton'),
        onPressed: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'La recuperación de contraseña se habilitará enseguida.',
                ),
              ),
            );
        },
        child: const Text('¿Olvidaste tu contraseña?'),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LoginBloc>().state;
    final loading = state.status.isInProgress;

    return PrimaryButton(
      key: const Key('loginWithEmailForm_loginButton'),
      text: loading ? 'Iniciando sesión...' : 'Iniciar sesión',
      enabled: state.valid && !loading,
      icon:
          loading
              ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : null,
      onPressed:
          loading
              ? null
              : () => context.read<LoginBloc>().add(const LoginSubmitted()),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('loginWithEmailForm_registerButton'),
      onPressed: () {
        Navigator.of(context).push<void>(RegisterPage.route());
      },
      child: const Text('Crear una cuenta institucional'),
    );
  }
}

class _InstitutionalAccessNotice extends StatelessWidget {
  const _InstitutionalAccessNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Text(
      'Se aceptan cuentas institucionales @tlalpan.tecnm.mx y cuentas '
      'autorizadas @tecnm.mx. Los permisos administrativos no se asignan '
      'automáticamente por el correo.',
      textAlign: TextAlign.center,
      style: AppTextStyle.captionL.copyWith(color: colors.deactive),
    );
  }
}
