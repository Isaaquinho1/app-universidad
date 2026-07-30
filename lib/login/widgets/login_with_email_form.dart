import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:go_router/go_router.dart';
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
          context.go('/feed');
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
      child: const _LoginContent(),
    );
  }
}

class _LoginContent extends StatelessWidget {
  const _LoginContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: surfaceColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LoginHeader(topInset: topInset),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.xlg,
                          AppSpacing.xlg,
                          AppSpacing.xlg,
                          AppSpacing.xxlg + bottomInset,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(34),
                          ),
                        ),
                        child: const AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FormIntroduction(),
                              SizedBox(height: AppSpacing.xlg),
                              _EmailInput(),
                              SizedBox(height: AppSpacing.lg),
                              _PasswordInput(),
                              SizedBox(height: AppSpacing.sm),
                              _RememberAndForgotRow(),
                              SizedBox(height: AppSpacing.xlg),
                              _LoginButton(),
                              SizedBox(height: AppSpacing.lg),
                              _AccountDivider(),
                              SizedBox(height: AppSpacing.lg),
                              _RegisterButton(),
                              SizedBox(height: AppSpacing.xlg),
                              _InstitutionalAccessNotice(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250 + topInset,
      child: Stack(
        children: [
          const Positioned.fill(child: _HeaderBackground()),
          Positioned(
            top: topInset + 14,
            left: AppSpacing.lg,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                key: const Key('loginWithEmailForm_backButton'),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: const Color(0xFF003B5C),
                tooltip: 'Regresar',
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xlg,
            right: AppSpacing.xlg,
            top: topInset + 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, color: Colors.white, size: 44),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Iniciar sesión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Accede a tu espacio institucional de Conecta ITT.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFDCEAF0),
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(44)),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF002A43),
                    Color(0xFF003B5C),
                    Color(0xFF075578),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -45,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -60,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            top: 65,
            right: -30,
            child: Transform.rotate(
              angle: -0.25,
              child: Container(
                width: 210,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormIntroduction extends StatelessWidget {
  const _FormIntroduction();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¡Bienvenid@ de nuevo!',
          textAlign: TextAlign.center,
          style: AppTextStyle.h4.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ingresa tu correo institucional y contraseña para continuar.',
          textAlign: TextAlign.center,
          style: AppTextStyle.body.copyWith(
            color: const Color(0xFF6C707A),
            height: 1.4,
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
      onChanged: (value) {
        context.read<LoginBloc>().add(LoginEmailChanged(value));
      },
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
      placeholder: 'Ingresa tu contraseña',
      obscureText: true,
      showPasswordToggle: true,
      autofillHints: const [AutofillHints.password],
      onChanged: (value) {
        context.read<LoginBloc>().add(LoginPasswordChanged(value));
      },
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

class _RememberAndForgotRow extends StatefulWidget {
  const _RememberAndForgotRow();

  @override
  State<_RememberAndForgotRow> createState() => _RememberAndForgotRowState();
}

class _RememberAndForgotRowState extends State<_RememberAndForgotRow> {
  bool _rememberMe = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            key: const Key('loginWithEmailForm_rememberMeCheckbox'),
            value: _rememberMe,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Recuérdame',
              style: TextStyle(
                color: Color(0xFF454851),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const Spacer(),
        TextButton(
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
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LoginBloc>().state;
    final loading = state.status.isInProgress;

    return SizedBox(
      height: 54,
      child: FilledButton(
        key: const Key('loginWithEmailForm_loginButton'),
        onPressed:
            !state.valid || loading
                ? null
                : () {
                  context.read<LoginBloc>().add(const LoginSubmitted());
                },
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF003B5C),
          disabledBackgroundColor: const Color(0xFFB9CFD9),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child:
            loading
                ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
                : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
      ),
    );
  }
}

class _AccountDivider extends StatelessWidget {
  const _AccountDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD7DAE2))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            '¿Primera vez en Conecta ITT?',
            style: TextStyle(color: Color(0xFF777B85), fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD7DAE2))),
      ],
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        key: const Key('loginWithEmailForm_registerButton'),
        onPressed: () {
          Navigator.of(context).push<void>(RegisterPage.route());
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF003B5C),
          side: const BorderSide(color: Color(0xFF003B5C), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Crear cuenta institucional',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _InstitutionalAccessNotice extends StatelessWidget {
  const _InstitutionalAccessNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: Color(0xFF075578),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Se aceptan cuentas @tlalpan.tecnm.mx y cuentas '
              'autorizadas @tecnm.mx.',
              style: TextStyle(
                color: Color(0xFF495473),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
