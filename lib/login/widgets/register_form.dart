import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/institutional_auth/institutional_auth.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:conecta_itt/login/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

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
      child: const _RegisterContent(),
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
                    'Posteriormente, un administrador deberá validar tu acceso '
                    'como docente o personal administrativo.'
                : state.availableGroups.isEmpty
                ? 'Revisa tu correo institucional para confirmar la cuenta. '
                    'Tu carrera y semestre fueron registrados, pero deberás '
                    'seleccionar un grupo cuando exista uno disponible.'
                : 'Revisa tu correo institucional para confirmar la cuenta. '
                    'Después podrás iniciar sesión en Conecta ITT.',
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

class _RegisterContent extends StatelessWidget {
  const _RegisterContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: surfaceColor,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(child: _RegisterHeader(topInset: topInset)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xlg,
              AppSpacing.xlg,
              AppSpacing.xlg,
              AppSpacing.xxlg + bottomInset,
            ),
            sliver: SliverToBoxAdapter(
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _FormIntroduction(),
                    const SizedBox(height: AppSpacing.xlg),
                    const _FullNameInput(),
                    const SizedBox(height: AppSpacing.lg),
                    const _EmailInput(),
                    const SizedBox(height: AppSpacing.md),
                    const _DetectedAccountInformation(),
                    const _DynamicAccountFields(),
                    const SizedBox(height: AppSpacing.lg),
                    const _PasswordInput(),
                    const SizedBox(height: AppSpacing.lg),
                    const _PasswordConfirmationInput(),
                    const SizedBox(height: AppSpacing.md),
                    const _PasswordRequirements(),
                    const SizedBox(height: AppSpacing.xlg),
                    const _TermsAcceptance(),
                    const SizedBox(height: AppSpacing.xlg),
                    const _RegisterButton(),
                    const SizedBox(height: AppSpacing.md),
                    const _BackToLoginButton(),
                    const SizedBox(height: AppSpacing.lg),
                    const _SecurityNotice(),
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

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 245 + topInset,
      child: Stack(
        children: [
          const Positioned.fill(child: _HeaderBackground()),
          Positioned(
            top: topInset + 14,
            left: AppSpacing.lg,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('registerForm_backButton'),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Regresar',
                color: const Color(0xFF003B5C),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          ),
          Positioned(
            top: topInset + 58,
            left: AppSpacing.xlg,
            right: AppSpacing.xlg,
            child: Column(
              children: [
                Icon(
                  Icons.person_add_alt_1_outlined,
                  color: Colors.white,
                  size: 44,
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Crear cuenta',
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
                  'Regístrate con una cuenta institucional del '
                  'TecNM Campus Tlalpan.',
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
          'Únete a Conecta ITT',
          textAlign: TextAlign.center,
          style: AppTextStyle.h4.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Completa tus datos para crear tu acceso institucional.',
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

class _FullNameInput extends StatefulWidget {
  const _FullNameInput();

  @override
  State<_FullNameInput> createState() => _FullNameInputState();
}

class _FullNameInputState extends State<_FullNameInput> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final fullName = context.select((RegisterBloc bloc) => bloc.state.fullName);

    return LabelledInput(
      key: const Key('registerForm_fullNameInput'),
      controller: _controller,
      label: 'Nombre completo',
      placeholder: 'Nombre y apellidos',
      autofillHints: const [AutofillHints.name],
      onChanged: (value) {
        context.read<RegisterBloc>().add(RegisterFullNameChanged(value));
      },
      errorText:
          fullName.isEmpty || fullName.trim().length >= 3
              ? null
              : 'Ingresa tu nombre completo.',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
      placeholder: 'l#########@tlalpan.tecnm.mx',
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [
        AutofillHints.username,
        AutofillHints.newUsername,
        AutofillHints.email,
      ],
      onChanged: (value) {
        context.read<RegisterBloc>().add(RegisterEmailChanged(value));
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
        state.isStudent
            ? 'Cuenta detectada: $label\n'
                'Número de control: ${state.controlNumber}'
            : 'Cuenta detectada: $label\n'
                'Tu acceso deberá ser autorizado por un administrador.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: Color(0xFF075578)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyle.body.copyWith(
                color: const Color(0xFF495473),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DynamicAccountFields extends StatelessWidget {
  const _DynamicAccountFields();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegisterBloc>().state;

    if (!state.email.isValid) {
      return const SizedBox.shrink();
    }

    if (state.isStaff) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: _StaffApprovalNotice(),
      );
    }

    if (state.isStudent) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: _AcademicFields(),
      );
    }

    return const SizedBox.shrink();
  }
}

class _AcademicFields extends StatelessWidget {
  const _AcademicFields();

  static const _semesters = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegisterBloc>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Información académica',
          style: AppTextStyle.h4.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        DropdownButtonFormField<String>(
          key: ValueKey('career-${state.careerId}'),
          initialValue: state.careerId,
          isExpanded: true,
          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          iconEnabledColor: Theme.of(context).colorScheme.onSurfaceVariant,
          decoration: _dropdownDecoration(
            context: context,
            label: 'Carrera',
            hint: 'Selecciona tu carrera',
          ),
          items: InstitutionalCareers.values
              .map(
                (career) => DropdownMenuItem<String>(
                  value: career.id,
                  child: Text(career.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            context.read<RegisterBloc>().add(RegisterCareerChanged(value));
          },
        ),

        const SizedBox(height: AppSpacing.lg),

        DropdownButtonFormField<int>(
          key: ValueKey('semester-${state.semester}'),
          initialValue: state.semester,
          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          iconEnabledColor: Theme.of(context).colorScheme.onSurfaceVariant,
          decoration: _dropdownDecoration(
            context: context,
            label: 'Semestre',
            hint: 'Selecciona tu semestre',
          ),
          items: _semesters
              .map(
                (semester) => DropdownMenuItem<int>(
                  value: semester,
                  child: Text('$semester.º semestre'),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            context.read<RegisterBloc>().add(RegisterSemesterChanged(value));
          },
        ),

        if (state.academicSelectionReady) ...[
          const SizedBox(height: AppSpacing.lg),
          _GroupField(state: state),
        ],
      ],
    );
  }
}

class _GroupField extends StatelessWidget {
  const _GroupField({required this.state});

  final RegisterState state;

  @override
  Widget build(BuildContext context) {
    return switch (state.groupsStatus) {
      AcademicGroupsStatus.initial => const SizedBox.shrink(),
      AcademicGroupsStatus.loading => const _CatalogMessage(
        icon: Icons.sync_rounded,
        text: 'Consultando los grupos disponibles...',
        showProgress: true,
      ),
      AcademicGroupsStatus.failure => const _CatalogMessage(
        icon: Icons.cloud_off_outlined,
        text:
            'No fue posible consultar los grupos. Revisa tu conexión e '
            'intenta cambiar nuevamente la carrera o el semestre.',
      ),
      AcademicGroupsStatus.success when state.availableGroups.isEmpty =>
        const _CatalogMessage(
          icon: Icons.info_outline_rounded,
          text:
              'Todavía no existen grupos configurados para esta carrera y '
              'semestre. Podrás seleccionarlo posteriormente.',
        ),
      AcademicGroupsStatus.success => DropdownButtonFormField<String>(
        key: ValueKey('group-${state.groupId}'),
        initialValue: state.groupId,
        isExpanded: true,
        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        iconEnabledColor: Theme.of(context).colorScheme.onSurfaceVariant,
        decoration: _dropdownDecoration(
          context: context,
          label: 'Grupo',
          hint: 'Selecciona tu grupo',
        ),
        items: state.availableGroups
            .map(
              (group) => DropdownMenuItem<String>(
                value: group.id,
                child: Text(group.name.toUpperCase()),
              ),
            )
            .toList(growable: false),
        onChanged: (value) {
          context.read<RegisterBloc>().add(RegisterGroupChanged(value));
        },
      ),
    };
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.text,
    this.showProgress = false,
  });

  final IconData icon;
  final String text;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9DDEA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showProgress)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 21, color: const Color(0xFF526184)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF586074),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffApprovalNotice extends StatelessWidget {
  const _StaffApprovalNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2D384)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF9A6B00)),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Las cuentas de docentes y personal administrativo requieren '
              'autorización. Crear la cuenta no asignará automáticamente '
              'permisos especiales.',
              style: TextStyle(
                color: Color(0xFF715314),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
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
      onChanged: (value) {
        context.read<RegisterBloc>().add(RegisterPasswordChanged(value));
      },
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
      onChanged: (value) {
        context.read<RegisterBloc>().add(
          RegisterPasswordConfirmationChanged(value),
        );
      },
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
    return const Text(
      'La contraseña debe contener al menos 8 caracteres, una mayúscula, '
      'una minúscula y un número.',
      style: TextStyle(color: Color(0xFF747986), fontSize: 12.5, height: 1.4),
    );
  }
}

class _TermsAcceptance extends StatelessWidget {
  const _TermsAcceptance();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegisterBloc>().state;
    final terms = state.termsDocument;
    final privacy = state.privacyDocument;

    if (state.legalDocumentsStatus == LegalDocumentsStatus.loading ||
        state.legalDocumentsStatus == LegalDocumentsStatus.initial) {
      return const _CatalogMessage(
        icon: Icons.description_outlined,
        text: 'Cargando Términos de Servicio y Política de Privacidad...',
        showProgress: true,
      );
    }

    if (state.legalDocumentsStatus == LegalDocumentsStatus.failure ||
        terms == null ||
        privacy == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CatalogMessage(
            icon: Icons.error_outline_rounded,
            text:
                'No fue posible cargar los documentos legales. '
                'No puedes completar el registro por el momento.',
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () {
              context.read<RegisterBloc>().add(
                const RegisterLegalDocumentsRequested(),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (terms.isDevelopment || privacy.isDevelopment) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF2D384)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: Color(0xFF9A6B00),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Los documentos legales actuales son versiones '
                    'provisionales para pruebas internas.',
                    style: TextStyle(
                      color: Color(0xFF715314),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: const Key('registerForm_termsCheckbox'),
              value: state.termsAccepted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (value) {
                context.read<RegisterBloc>().add(
                  RegisterTermsAcceptanceChanged(value ?? false),
                );
              },
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Al registrarte, aceptas nuestros ',
                      style: TextStyle(
                        color: Color(0xFF555A66),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    _LegalLink(document: terms),
                    const Text(
                      ' y nuestra ',
                      style: TextStyle(
                        color: Color(0xFF555A66),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    _LegalLink(document: privacy),
                    const Text(
                      '.',
                      style: TextStyle(color: Color(0xFF555A66), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        showDialog<void>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(document.title),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (document.isDevelopment) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Documento provisional para pruebas internas. '
                            'Será sustituido por la versión institucional '
                            'antes del lanzamiento.',
                            style: TextStyle(
                              color: Color(0xFF715314),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Text(
                        document.content,
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Versión: ${document.version}',
                        style: const TextStyle(
                          color: Color(0xFF747986),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
        );
      },
      child: Text(
        document.isTerms ? 'Términos de Servicio' : 'Política de Privacidad',
        style: const TextStyle(
          color: Color(0xFF003B5C),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RegisterBloc>().state;
    final loading = state.status.isInProgress;

    return SizedBox(
      height: 54,
      child: FilledButton(
        key: const Key('registerForm_submitButton'),
        onPressed:
            !state.valid || loading
                ? null
                : () {
                  context.read<RegisterBloc>().add(const RegisterSubmitted());
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
                      'Crear cuenta institucional',
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

class _BackToLoginButton extends StatelessWidget {
  const _BackToLoginButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('registerForm_loginButton'),
      onPressed: () {
        Navigator.of(
          context,
        ).pushReplacement<void, void>(LoginWithEmailPage.route());
      },
      child: const Text('Ya tengo una cuenta'),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

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
          Icon(Icons.security_outlined, size: 20, color: Color(0xFF075578)),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Los permisos institucionales se administran de forma segura. '
              'Ninguna cuenta puede asignarse por sí misma privilegios de '
              'docente, administrador o superadministrador.',
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

InputDecoration _dropdownDecoration({
  required BuildContext context,
  required String label,
  required String hint,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  final fillColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF7F8FC);
  final borderColor =
      isDark ? const Color(0xFF55555A) : const Color(0xFFD4D8E3);
  final focusedBorderColor =
      isDark ? const Color(0xFF5FA8C6) : const Color(0xFF003B5C);

  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: fillColor,
    labelStyle: TextStyle(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: TextStyle(
      color: focusedBorderColor,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: TextStyle(color: colors.onSurfaceVariant),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.lg,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
    ),
  );
}
