import 'dart:async';

import 'package:conecta_itt/institutional_auth/institutional_auth.dart';
import 'package:conecta_itt/login/register_bloc/register_bloc.dart';
import 'package:conecta_itt/login/services/biometric_login_service.dart';
import 'package:conecta_itt/login/services/password_recovery_session_controller.dart';
import 'package:conecta_itt/login/services/supabase_password_recovery_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _RecoveryStep { email, code, password, completed }

/// Password recovery flow for institutional accounts.
class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  static const _navy = Color(0xFF003B5C);

  late final SupabasePasswordRecoveryService _service;

  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  final _biometrics = BiometricLoginService();

  _RecoveryStep _step = _RecoveryStep.email;

  bool _busy = false;
  bool _allowPop = false;
  bool _passwordVisible = false;
  bool _confirmationVisible = false;
  bool _cleanupRequired = false;

  String? _error;
  String? _notice;

  DateTime? _resendAvailableAt;

  Timer? _resendTimer;

  String get _email => _emailController.text.trim().toLowerCase();

  int get _resendSeconds {
    final availableAt = _resendAvailableAt;

    if (availableAt == null) return 0;

    final remaining = availableAt.difference(DateTime.now()).inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  @override
  void initState() {
    super.initState();

    _service = context.read<SupabasePasswordRecoveryService>();

    _emailController = TextEditingController(text: widget.initialEmail);
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _error = message;
      _notice = null;
    });
  }

  bool _validateEmail() {
    if (!InstitutionalEmail.parse(_email).isValid) {
      _showError('Ingresa un correo institucional válido.');
      return false;
    }

    return true;
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();

    _resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {});

      if (_resendSeconds == 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _run(
    Future<void> Function() operation, {
    required String failureMessage,
  }) async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      await operation();
    } catch (_) {
      _showError(failureMessage);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      } else {
        await _cleanupAfterDisposal();
      }
    }
  }

  Future<void> _cleanupAfterDisposal() async {
    try {
      final status = await _service.getStatus();

      if (status != PasswordRecoverySessionStatus.signedOut &&
          status != PasswordRecoverySessionStatus.normal) {
        await _service.cancelRecovery();
      }
    } catch (_) {
      // Startup reconciliation will retry interrupted cleanup.
    }
  }

  Future<void> _requestCode() async {
    if (!_validateEmail() || _resendSeconds > 0) return;

    await _run(
      () async {
        await _service.requestRecoveryEmail(email: _email);

        if (!mounted) return;

        setState(() {
          _step = _RecoveryStep.code;
          _notice =
              'Si existe una cuenta asociada a este correo, '
              'recibirás un código de recuperación.';
        });

        _startResendCooldown();
      },
      failureMessage:
          'No fue posible solicitar el código. '
          'Espera unos minutos e inténtalo nuevamente.',
    );
  }

  void _useExistingCode() {
    if (!_validateEmail() || _busy) return;

    setState(() {
      _error = null;
      _notice = null;
      _step = _RecoveryStep.code;
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      _showError('Introduce el código recibido por correo.');
      return;
    }

    await _run(
      () async {
        // Verification must succeed before showing password fields.
        await _service.verifyRecoveryCode(email: _email, code: code);

        if (!mounted) return;

        _codeController.clear();

        setState(() {
          _step = _RecoveryStep.password;
        });
      },
      failureMessage:
          'No fue posible verificar el código. '
          'Comprueba que sea correcto y que no haya expirado.',
    );
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmationController.text;

    if (!RegisterPassword.dirty(password).isValid) {
      _showError('La contraseña debe cumplir todos los requisitos.');
      return;
    }

    if (password != confirmation) {
      _showError('Las contraseñas no coinciden.');
      return;
    }

    await _run(
      () async {
        // Only invalidate biometric credentials for this account.
        final credentials = await _biometrics.readCredentials();

        if (credentials?.email.trim().toLowerCase() == _email) {
          await _biometrics.clearCredentials();
        }

        try {
          await _service.completeRecovery(
            password: password,
            confirmation: confirmation,
          );
        } on PasswordRecoveryRejectedException catch (error) {
          if (!mounted) return;

          _passwordController.clear();
          _confirmationController.clear();

          setState(() {
            _passwordVisible = false;
            _confirmationVisible = false;
            _cleanupRequired = false;
          });

          _showError(
            error.code == 'same_password'
                ? 'Tu nueva contraseña debe ser diferente '
                    'de la anterior. Introduce otra contraseña.'
                : 'La contraseña no cumple los requisitos '
                    'de seguridad. Introduce una diferente.',
          );

          return;
        } catch (_) {
          if (!mounted) rethrow;

          _passwordController.clear();
          _confirmationController.clear();

          setState(() {
            _passwordVisible = false;
            _confirmationVisible = false;
            _cleanupRequired = true;
          });

          rethrow;
        }

        if (!mounted) return;

        _passwordController.clear();
        _confirmationController.clear();

        setState(() {
          _step = _RecoveryStep.completed;
        });
      },
      failureMessage:
          'No fue posible confirmar que el proceso haya terminado. '
          'Cancela la recuperación e intenta iniciar sesión.',
    );
  }

  Future<void> _leave() async {
    if (_busy) return;

    if (_step == _RecoveryStep.completed) {
      _close(true);
      return;
    }

    await _run(
      () async {
        await _service.cancelRecovery();

        if (!mounted) return;

        _close(false);
      },
      failureMessage:
          'No fue posible cerrar la recuperación de forma segura. '
          'Inténtalo nuevamente.',
    );
  }

  void _close(bool completed) {
    if (!mounted) return;

    setState(() => _allowPop = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(completed);
      }
    });
  }

  String get _title => switch (_step) {
    _RecoveryStep.email => 'Recuperar contraseña',
    _RecoveryStep.code => 'Verifica tu correo',
    _RecoveryStep.password => 'Nueva contraseña',
    _RecoveryStep.completed => '¡Todo listo!',
  };

  String get _subtitle => switch (_step) {
    _RecoveryStep.email => 'Recupera el acceso a tu cuenta institucional.',
    _RecoveryStep.code => 'Introduce el código que recibiste por correo.',
    _RecoveryStep.password =>
      'Crea una nueva contraseña para proteger tu cuenta.',
    _RecoveryStep.completed => 'Tu contraseña se actualizó correctamente.',
  };

  IconData get _stepIcon => switch (_step) {
    _RecoveryStep.email => Icons.lock_outline_rounded,
    _RecoveryStep.code => Icons.mark_email_read_outlined,
    _RecoveryStep.password => Icons.shield_outlined,
    _RecoveryStep.completed => Icons.check_circle_outline_rounded,
  };

  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(44)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF002A43), Color(0xFF003B5C), Color(0xFF075578)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Regresar',
                    color: _navy,
                    onPressed: _busy ? null : _leave,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
              ),
              Icon(_stepIcon, color: Colors.white, size: 48),
              const SizedBox(height: 14),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFDCEAF0),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    return Row(
      children: List.generate(4, (index) {
        final active = index <= _step.index;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 5,
            decoration: BoxDecoration(
              color:
                  active
                      ? const Color(0xFF3C91B8)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }),
    );
  }

  Widget _primaryButton(String label, VoidCallback? action) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child:
            _busy
                ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.3),
                )
                : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _emailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Correo de recuperación',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'Utiliza el mismo correo con el que registraste '
          'tu cuenta de Conecta ITT.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          decoration: _decoration(
            'Correo institucional',
            Icons.mail_outline_rounded,
          ),
        ),
        const SizedBox(height: 24),
        _primaryButton('Enviar código', _requestCode),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : _useExistingCode,
          child: const Text('Ya tengo un código'),
        ),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Correo asociado a la recuperación:'),
        const SizedBox(height: 8),
        Text(_email, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          autocorrect: false,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _decoration('Código de verificación', Icons.pin_outlined),
        ),
        const SizedBox(height: 24),
        _primaryButton('Verificar código', _verifyCode),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy || _resendSeconds > 0 ? null : _requestCode,
          child: Text(
            _resendSeconds > 0
                ? 'Reenviar en $_resendSeconds s'
                : 'Reenviar código',
          ),
        ),
        TextButton(
          onPressed:
              _busy
                  ? null
                  : () {
                    _codeController.clear();

                    setState(() {
                      _step = _RecoveryStep.email;
                      _error = null;
                      _notice = null;
                    });
                  },
          child: const Text('Cambiar correo'),
        ),
      ],
    );
  }

  Widget _requirement(String label, bool valid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            valid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 19,
            color:
                valid
                    ? Colors.green
                    : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _passwordStep() {
    final password = _passwordController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _passwordController,
          enabled: !_busy && !_cleanupRequired,
          obscureText: !_passwordVisible,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: _decoration(
            'Nueva contraseña',
            Icons.lock_outline_rounded,
            suffix: IconButton(
              tooltip: 'Mostrar u ocultar contraseña',
              onPressed:
                  () => setState(() => _passwordVisible = !_passwordVisible),
              icon: Icon(
                _passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmationController,
          enabled: !_busy && !_cleanupRequired,
          obscureText: !_confirmationVisible,
          autocorrect: false,
          enableSuggestions: false,
          decoration: _decoration(
            'Confirmar contraseña',
            Icons.lock_outline_rounded,
            suffix: IconButton(
              tooltip: 'Mostrar u ocultar confirmación',
              onPressed:
                  () => setState(
                    () => _confirmationVisible = !_confirmationVisible,
                  ),
              icon: Icon(
                _confirmationVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _requirement('Al menos 8 caracteres', password.length >= 8),
        _requirement('Una letra mayúscula', RegExp('[A-Z]').hasMatch(password)),
        _requirement('Una letra minúscula', RegExp('[a-z]').hasMatch(password)),
        _requirement('Un número', RegExp(r'\d').hasMatch(password)),
        const SizedBox(height: 24),
        _primaryButton(
          'Restablecer contraseña',
          _cleanupRequired ? null : _updatePassword,
        ),
      ],
    );
  }

  Widget _completedStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 82,
          color: Colors.green,
        ),
        const SizedBox(height: 20),
        Text(
          '¡Contraseña actualizada!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Ya puedes acceder a Conecta ITT con tu nueva contraseña.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _primaryButton('Volver a iniciar sesión', _leave),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) {
          unawaited(_leave());
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colors.surface,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _progress(),
                          const SizedBox(height: 30),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: colors.onErrorContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (_notice != null) ...[
                            Text(
                              _notice!,
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 20),
                          ],
                          switch (_step) {
                            _RecoveryStep.email => _emailStep(),
                            _RecoveryStep.code => _codeStep(),
                            _RecoveryStep.password => _passwordStep(),
                            _RecoveryStep.completed => _completedStep(),
                          },
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer?.cancel();

    if (!_busy && _step != _RecoveryStep.completed) {
      unawaited(_cleanupAfterDisposal());
    }

    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();

    super.dispose();
  }
}
