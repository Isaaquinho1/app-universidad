import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:conecta_itt/institutional_auth/institutional_auth.dart';
import 'package:conecta_itt/login/login.dart';

/// Institutional account registration form.
class RegisterForm extends StatelessWidget {
  const RegisterForm({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterBloc, RegisterState>(
      listenWhen:
          (previous, current) =>
              previous.status != current.status ||
              previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.status.isFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage ??
                      'No fue posible crear la cuenta institucional.',
                ),
              ),
            );
          return;
        }

        if (state.status.isSuccess) {
          _showRegistrationSuccessDialog(context, state);
        }
      },
      child: const SafeArea(
        child: AutofillGroup(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xlg,
                  AppSpacing.lg,
                  AppSpacing.xlg,
                  AppSpacing.xxlg,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(),
                      SizedBox(height: AppSpacing.xxxlg),
                      _EmailInput(),
                      SizedBox(height: AppSpacing.md),
                      _DetectedAccountInformation(),
                      SizedBox(height: AppSpacing.lg),
                      _PasswordInput(),
                      SizedBox(height: AppSpacing.lg),
                      _PasswordConfirmationInput(),
                      SizedBox(height: AppSpacing.xlg),
                      _PasswordRequirements(),
                      SizedBox(height: AppSpacing.xxxlg),
                      _RegisterButton(),
                      SizedBox(height: AppSpacing.md),
                      _BackToLoginButton(),
                      SizedBox(height: AppSpacing.lg),
                      _SecurityNotice(),
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

  Future<void> _showRegistrationSuccessDialog(
    BuildContext context,
    RegisterState state,
  ) async {
    final isStaff = state.emailType.isStaff;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cuenta creada'),
          content: Text(
            isStaff
                ? 'Revisa tu correo institucional para confirmar la cuenta. '
                    'Después de la confirmación, el personal docente o '
                    'administrativo deberá ser autorizado para recibir '
                    'permisos especiales.'
                : 'Revisa tu correo institucional para confirmar la cuenta. '
                    'Después podrás iniciar sesión y completar tu perfil '
                    'académico.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Volver al inicio de sesión'),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear cuenta institucional',
          style: AppTextStyle.h4.copyWith(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Regístrate con una cuenta oficial del TecNM Campus Tlalpan.',
          style: AppTextStyle.body.copyWith(color: colors.deactive),
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
    final email = context.select((RegisterBloc bloc) => bloc.state.email);

    return LabelledInput(
      key: const Key('registerForm_emailInput'),
      controller: _controller,
      label: 'Correo institucional',
      placeholder: 'correo@tlalpan.tecnm.mx',
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [
        AutofillHints.username,
        AutofillHints.newUsername,
        AutofillHints.email,
      ],
      onChanged:
          (value) =>
              context.read<RegisterBloc>().add(RegisterEmailChanged(value)),
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

class _DetectedAccountInformation extends StatelessWidget {
  const _DetectedAccountInformation();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegisterBloc>().state;

    if (!state.email.isValid) {
      return const SizedBox.shrink();
    }

    final label = switch (state.emailType) {
      InstitutionalEmailType.student => 'Estudiante',
      InstitutionalEmailType.campusStaff =>
        'Docente o personal del Campus Tlalpan',
      InstitutionalEmailType.tecnmStaff => 'Personal del TecNM',
      InstitutionalEmailType.invalid => 'Correo no válido',
    };

    final message =
        state.emailType.isStudent
            ? 'Tipo detectado: $label\n'
                'Número de control: ${state.controlNumber ?? 'No disponible'}'
            : 'Tipo detectado: $label\n'
                'La cuenta requerirá autorización para obtener permisos '
                'administrativos o docentes.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          context,
        ).extension<AppColors>()!.primary.withValues(alpha: 0.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTextStyle.body)),
        ],
      ),
    );
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
    final password = context.select((RegisterBloc bloc) => bloc.state.password);

    return LabelledInput(
      key: const Key('registerForm_passwordInput'),
      controller: _controller,
      label: 'Contraseña',
      placeholder: 'Crea una contraseña segura',
      obscureText: true,
      showPasswordToggle: true,
      autofillHints: const [AutofillHints.newPassword],
      onChanged:
          (value) =>
              context.read<RegisterBloc>().add(RegisterPasswordChanged(value)),
      errorText: _passwordError(password),
    );
  }

  String? _passwordError(RegisterPassword password) {
    if (password.isPure || password.isValid) {
      return null;
    }

    return switch (password.error) {
      RegisterPasswordValidationError.tooShort =>
        'Debe contener al menos 8 caracteres.',
      RegisterPasswordValidationError.missingUppercase =>
        'Debe incluir una letra mayúscula.',
      RegisterPasswordValidationError.missingLowercase =>
        'Debe incluir una letra minúscula.',
      RegisterPasswordValidationError.missingNumber =>
        'Debe incluir al menos un número.',
      null => null,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PasswordConfirmationInput extends StatefulWidget {
  const _PasswordConfirmationInput();

  @override
  State<_PasswordConfirmationInput> createState() =>
      _PasswordConfirmationInputState();
}

class _PasswordConfirmationInputState
    extends State<_PasswordConfirmationInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final confirmation = context.select(
      (RegisterBloc bloc) => bloc.state.passwordConfirmation,
    );

    return LabelledInput(
      key: const Key('registerForm_passwordConfirmationInput'),
      controller: _controller,
      label: 'Confirmar contraseña',
      placeholder: 'Escribe nuevamente tu contraseña',
      obscureText: true,
      showPasswordToggle: true,
      autofillHints: const [AutofillHints.newPassword],
      onChanged:
          (value) => context.read<RegisterBloc>().add(
            RegisterPasswordConfirmationChanged(value),
          ),
      errorText:
          confirmation.isPure || confirmation.isValid
              ? null
              : confirmation.error ==
                  RegisterPasswordConfirmationValidationError.empty
              ? 'Confirma tu contraseña.'
              : 'Las contraseñas no coinciden.',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Text(
      'La contraseña debe contener al menos 8 caracteres, una mayúscula, '
      'una minúscula y un número.',
      style: AppTextStyle.captionL.copyWith(color: colors.deactive),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegisterBloc>().state;
    final loading = state.status.isInProgress;

    return PrimaryButton(
      key: const Key('registerForm_submitButton'),
      text: loading ? 'Creando cuenta...' : 'Crear cuenta',
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
              : () =>
                  context.read<RegisterBloc>().add(const RegisterSubmitted()),
    );
  }
}

class _BackToLoginButton extends StatelessWidget {
  const _BackToLoginButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Ya tengo una cuenta'),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Text(
      'Crear una cuenta con correo institucional no otorga automáticamente '
      'permisos de administrador. Los roles especiales se asignan mediante '
      'un proceso de autorización.',
      textAlign: TextAlign.center,
      style: AppTextStyle.captionL.copyWith(color: colors.deactive),
    );
  }
}
