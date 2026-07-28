import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:conecta_itt/login/login.dart';

/// Initial institutional access screen for unauthenticated users.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  static const _logoPath = 'assets/branding/conecta_itt_logo_clean.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    return Scaffold(
      backgroundColor: const Color(0xFF1A32D6),
      body: Stack(
        children: [
          const Positioned.fill(child: _HeroBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlg),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: ClipRect(
                              child: Transform.scale(
                                scale: 2.75,
                                child: Image.asset(
                                  _logoPath,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  semanticLabel: 'Logo de Conecta ITT',
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Text(
                            'Conecta ITT',
                            textAlign: TextAlign.center,
                            style: AppTextStyle.h4.copyWith(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          Text(
                            'Tu comunidad universitaria, siempre conectada.',
                            textAlign: TextAlign.center,
                            style: AppTextStyle.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            child: Text(
                              'Consulta comunicados, servicios y contenido '
                              'personalizado del TecNM Campus Tlalpan.',
                              textAlign: TextAlign.center,
                              style: AppTextStyle.captionL.copyWith(
                                color: Colors.white.withValues(alpha: 0.84),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  _AccessCard(colors: colors),

                  const SizedBox(height: AppSpacing.xlg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A32D6), Color(0xFF2348F0), Color(0xFF273CDA)],
            ),
          ),
        ),

        Positioned(
          top: -90,
          left: -60,
          child: _BlurCircle(
            size: 220,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          top: 90,
          right: -70,
          child: _BlurCircle(
            size: 220,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          bottom: 210,
          left: -80,
          child: _BlurCircle(
            size: 240,
            color: Colors.white.withValues(alpha: 0.09),
          ),
        ),
        Positioned(
          bottom: -40,
          right: -60,
          child: _BlurCircle(
            size: 220,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),

        Positioned(
          top: 70,
          left: -30,
          child: _SoftShape(
            width: 220,
            height: 90,
            angle: -0.35,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        Positioned(
          top: 160,
          right: -20,
          child: _SoftShape(
            width: 180,
            height: 70,
            angle: 0.28,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        Positioned(
          bottom: 260,
          right: 30,
          child: _SoftShape(
            width: 160,
            height: 70,
            angle: -0.20,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlg,
        AppSpacing.xlg,
        AppSpacing.xlg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bienvenido a Conecta ITT',
            textAlign: TextAlign.center,
            style: AppTextStyle.h4.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF222222),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Inicia sesión o crea tu cuenta institucional para continuar.',
            textAlign: TextAlign.center,
            style: AppTextStyle.body.copyWith(
              color: const Color(0xFF666666),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xlg),

          SizedBox(
            height: 54,
            child: FilledButton(
              key: const Key('welcomePage_loginButton'),
              onPressed: () {
                Navigator.of(context).push<void>(LoginWithEmailPage.route());
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C61F4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Iniciar sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          SizedBox(
            height: 54,
            child: OutlinedButton(
              key: const Key('welcomePage_registerButton'),
              onPressed: () {
                Navigator.of(context).push<void>(RegisterPage.route());
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C61F4),
                side: const BorderSide(color: Color(0xFF2C61F4), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Crear cuenta institucional',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Acceso exclusivo para la comunidad del TecNM Campus Tlalpan.',
            textAlign: TextAlign.center,
            style: AppTextStyle.captionL.copyWith(
              color: const Color(0xFF7A7A7A),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SoftShape extends StatelessWidget {
  const _SoftShape({
    required this.width,
    required this.height,
    required this.angle,
    required this.color,
  });

  final double width;
  final double height;
  final double angle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(40),
        ),
      ),
    );
  }
}
