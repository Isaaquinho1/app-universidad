import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Presentación institucional de Conecta ITT.
///
/// Esta pantalla es únicamente visual. La navegación y la duración
/// de su presentación serán controladas por el arranque de la app.
class InstitutionalSplashPage extends StatelessWidget {
  const InstitutionalSplashPage({super.key, this.showLoading = true});

  final bool showLoading;

  static const _navy = Color(0xFF003B5C);
  static const _deepNavy = Color(0xFF07182B);
  static const _gold = Color(0xFFD6AC61);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;

    return Scaffold(
      backgroundColor: _deepNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final titleSize = math.min(47.0, width * 0.115);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Fondo institucional.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF123E67), _navy, _deepNavy],
                  ),
                ),
              ),

              // Fotografía real del Campus Tlalpan.
              Positioned(
                top: height * 0.55,
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: const _CampusWaveClipper(),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/campus/campus_splash.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) {
                          return const ColoredBox(color: _navy);
                        },
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xAD003B5C),
                              Color(0x7B003B5C),
                              Color(0xE807182B),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Curvas doradas y azules de la composición.
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _SplashAccentsPainter()),
                ),
              ),

              // Firmas oficiales del campus.
              Positioned(
                top: safeTop + 24,
                left: 18,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: SvgPicture.asset(
                          'assets/branding/institutional/sep_logo_2026.svg',
                          height: 43,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SvgPicture.asset(
                          'assets/branding/institutional/tecnm_logo.svg',
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SvgPicture.asset(
                          'assets/branding/institutional/tlalpan_logo.svg',
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Identidad de la aplicación: sin birrete.
              Positioned(
                top: height * 0.32,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Conecta ',
                              style: TextStyle(color: Colors.white),
                            ),
                            const TextSpan(
                              text: 'ITT',
                              style: TextStyle(color: _gold),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          shadows: const [
                            Shadow(color: Color(0x55000000), blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    const Text(
                      'TU COMUNIDAD UNIVERSITARIA,\nSIEMPRE CONECTADA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),

              // Indicador real de carga, no incrustado en la foto.
              if (showLoading)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: safeBottom + 30,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 27,
                        height: 27,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(_gold),
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Cargando Conecta ITT...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CampusWaveClipper extends CustomClipper<Path> {
  const _CampusWaveClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.14)
      ..cubicTo(
        size.width * 0.30,
        -size.height * 0.035,
        size.width * 0.68,
        size.height * 0.11,
        size.width,
        size.height * 0.025,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SplashAccentsPainter extends CustomPainter {
  const _SplashAccentsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint =
        Paint()
          ..color = InstitutionalSplashPage._gold.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.3;

    final goldCurve =
        Path()
          ..moveTo(-20, size.height * 0.65)
          ..cubicTo(
            size.width * 0.28,
            size.height * 0.52,
            size.width * 0.68,
            size.height * 0.65,
            size.width + 20,
            size.height * 0.56,
          );

    canvas.drawPath(goldCurve, goldPaint);

    final subtlePaint =
        Paint()
          ..color = const Color(0xFF7DB4D2).withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;

    final subtleCurve =
        Path()
          ..moveTo(-25, size.height * 0.70)
          ..cubicTo(
            size.width * 0.30,
            size.height * 0.59,
            size.width * 0.72,
            size.height * 0.69,
            size.width + 25,
            size.height * 0.60,
          );

    canvas.drawPath(subtleCurve, subtlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
