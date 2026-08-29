import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/app/app.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Administrative scanner for validating dynamic institutional student IDs.
class AdminStudentIdValidatorPage extends StatefulWidget {
  const AdminStudentIdValidatorPage({super.key});

  @override
  State<AdminStudentIdValidatorPage> createState() =>
      _AdminStudentIdValidatorPageState();
}

class _AdminStudentIdValidatorPageState
    extends State<AdminStudentIdValidatorPage> {
  late final MobileScannerController _scannerController;

  bool _isProcessing = false;
  bool _codeDetected = false;
  bool _scannerPaused = true;
  bool _scannerStarting = false;
  int _scannerSession = 0;

  StudentIdQrValidationResult? _result;
  String? _processingError;

  String? _lastToken;
  DateTime? _lastDetectionAt;

  @override
  void initState() {
    super.initState();

    _scannerController = MobileScannerController(
      autoStart: false,
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
      returnImage: false,
      autoZoom: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanner();
    });
  }

  Future<void> _startScanner() async {
    if (_scannerStarting || !_scannerPaused) {
      return;
    }

    _scannerStarting = true;

    try {
      await _scannerController.start();

      if (!mounted) {
        return;
      }

      setState(() {
        _scannerPaused = false;
        _processingError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Student ID scanner start error: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _scannerPaused = true;
        _processingError =
            'No fue posible acceder a la cámara. '
            'Revisa el permiso e inténtalo nuevamente.';
      });
    } finally {
      _scannerStarting = false;
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isProcessing || _scannerPaused) {
      return;
    }

    String? token;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();

      if (rawValue != null && rawValue.isNotEmpty) {
        token = rawValue;
        break;
      }
    }

    if (token == null) {
      return;
    }

    final now = DateTime.now();
    final repeatedImmediately =
        token == _lastToken &&
        _lastDetectionAt != null &&
        now.difference(_lastDetectionAt!) < const Duration(seconds: 2);

    if (repeatedImmediately) {
      return;
    }

    _lastToken = token;
    _lastDetectionAt = now;

    if (!token.startsWith('itt1_')) {
      await _showInvalidFormat();
      return;
    }

    final repository = context.read<StudentIdQrRepository>();
    final feedbackStartedAt = DateTime.now();

    setState(() {
      _isProcessing = true;
      _codeDetected = true;
      _processingError = null;
    });

    unawaited(HapticFeedback.mediumImpact());

    try {
      await _scannerController.pause();
      _scannerPaused = true;

      final validationFuture = repository.validateToken(token);

      await _waitForMinimumDetectionFeedback(feedbackStartedAt);

      final result = await validationFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (error, stackTrace) {
      debugPrint('Student ID validation error: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _processingError =
            'No fue posible validar el código. '
            'Verifica la conexión e inténtalo nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showInvalidFormat() async {
    if (_isProcessing) {
      return;
    }

    final feedbackStartedAt = DateTime.now();

    setState(() {
      _isProcessing = true;
      _codeDetected = true;
    });

    unawaited(HapticFeedback.mediumImpact());

    try {
      await _scannerController.pause();
      _scannerPaused = true;

      await _waitForMinimumDetectionFeedback(feedbackStartedAt);

      if (!mounted) {
        return;
      }

      setState(() {
        _result = StudentIdQrValidationResult(
          valid: false,
          reason: 'invalid_format',
          validatedAt: DateTime.now().toUtc(),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _scanAnother() async {
    if (_scannerStarting) {
      return;
    }

    setState(() {
      _result = null;
      _processingError = null;
      _codeDetected = false;
      _lastToken = null;
      _lastDetectionAt = null;
      _scannerPaused = true;
      _scannerSession++;
    });

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) {
      return;
    }

    await _startScanner();
  }

  Future<void> _waitForMinimumDetectionFeedback(DateTime startedAt) async {
    const minimumDuration = Duration(milliseconds: 900);
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = minimumDuration - elapsed;

    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<void> _retryValidation() async {
    final token = _lastToken;

    if (token == null || token.isEmpty) {
      await _scanAnother();
      return;
    }

    setState(() {
      _processingError = null;
      _isProcessing = true;
    });

    try {
      final result = await context.read<StudentIdQrRepository>().validateToken(
        token,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (error, stackTrace) {
      debugPrint('Student ID validation retry error: $error\n$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _processingError =
            'No fue posible validar el código. '
            'Verifica la conexión e inténtalo nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (error, stackTrace) {
      debugPrint('Student ID scanner torch error: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppBloc>().state.institutionalProfile;

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!profile.canValidateStudentIds) {
      return Scaffold(
        appBar: AppBar(title: const Text('Validar identificación')),
        body: const _UnauthorizedValidatorState(),
      );
    }

    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validar identificación'),
        actions: [
          if (result == null)
            IconButton(
              tooltip: 'Linterna',
              onPressed: _toggleTorch,
              icon: const Icon(Icons.flashlight_on_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child:
            result == null
                ? _buildScanner()
                : _ValidationResultView(
                  result: result,
                  onScanAnother: _scanAnother,
                ),
      ),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              Text(
                'Escanea el código de la identificación',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'El código debe estar visible y dentro del marco.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    key: ValueKey<int>(_scannerSession),
                    controller: _scannerController,
                    onDetect: _handleDetection,
                    errorBuilder:
                        (context, error) => _ScannerErrorState(
                          error: error,
                          onRetry: _scanAnother,
                        ),
                    placeholderBuilder:
                        (context) => const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                  ),
                  _ScannerOverlay(detected: _codeDetected),
                  if (_isProcessing)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.46),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Column(
                            key: ValueKey<bool>(_codeDetected),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF20D7A0,
                                  ).withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF20D7A0),
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: Color(0xFF20D7A0),
                                  size: 42,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const Text(
                                'Código detectado',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              const Text(
                                'Validando identificación…',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_processingError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: _ValidationConnectionError(
              message: _processingError!,
              onRetry: _isProcessing ? null : _retryValidation,
              onScanAnother: _isProcessing ? null : _scanAnother,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            104,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleTorch,
                  icon: const Icon(Icons.flashlight_on_outlined),
                  label: const Text('Linterna'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    super.dispose();
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.detected});

  final bool detected;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _ScannerOverlayPainter(detected: detected)),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({required this.detected});

  final bool detected;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = size.width < size.height ? size.width : size.height;

    final squareSize = (shortestSide * 0.72).clamp(220.0, 320.0);

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: squareSize,
      height: squareSize,
    );

    final overlayPath =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(
            RRect.fromRectAndRadius(scanRect, const Radius.circular(24)),
          )
          ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.52),
    );

    if (detected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(scanRect, const Radius.circular(24)),
        Paint()
          ..color = const Color(0xFF20D7A0).withValues(alpha: 0.22)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(24)),
      Paint()
        ..color = detected ? const Color(0xFF20D7A0) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = detected ? 5 : 3,
    );

    const cornerLength = 34.0;
    const cornerWidth = 6.0;
    const cornerRadius = 24.0;

    final cornerPaint =
        Paint()
          ..color = const Color(0xFF20D7A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cornerWidth
          ..strokeCap = StrokeCap.round;

    final left = scanRect.left;
    final top = scanRect.top;
    final right = scanRect.right;
    final bottom = scanRect.bottom;

    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerRadius)
        ..lineTo(left, top + cornerLength)
        ..moveTo(left + cornerRadius, top)
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(right, top + cornerRadius)
        ..lineTo(right, top + cornerLength)
        ..moveTo(right - cornerRadius, top)
        ..lineTo(right - cornerLength, top),
      cornerPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - cornerRadius)
        ..lineTo(left, bottom - cornerLength)
        ..moveTo(left + cornerRadius, bottom)
        ..lineTo(left + cornerLength, bottom),
      cornerPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(right, bottom - cornerRadius)
        ..lineTo(right, bottom - cornerLength)
        ..moveTo(right - cornerRadius, bottom)
        ..lineTo(right - cornerLength, bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.detected != detected;
  }
}

class _ValidationResultView extends StatelessWidget {
  const _ValidationResultView({
    required this.result,
    required this.onScanAnother,
  });

  final StudentIdQrValidationResult result;
  final Future<void> Function() onScanAnother;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        104,
      ),
      children: [
        _ValidationStatusHeader(result: result),
        const SizedBox(height: AppSpacing.lg),
        if (result.valid)
          _ValidStudentResult(result: result)
        else
          _InvalidStudentResult(result: result),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: onScanAnother,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Escanear otro código'),
        ),
      ],
    );
  }
}

class _ValidationStatusHeader extends StatelessWidget {
  const _ValidationStatusHeader({required this.result});

  final StudentIdQrValidationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background =
        result.valid
            ? const Color(0xFFE5F8F1)
            : theme.colorScheme.errorContainer;

    final foreground =
        result.valid
            ? const Color(0xFF006B50)
            : theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            result.valid ? Icons.verified_rounded : Icons.gpp_bad_rounded,
            size: 64,
            color: foreground,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.valid ? 'Identificación válida' : 'Identificación no válida',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.valid
                ? 'La información fue verificada por el servidor institucional.'
                : _validationReasonLabel(result.reason),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _ValidStudentResult extends StatelessWidget {
  const _ValidStudentResult({required this.result});

  final StudentIdQrValidationResult result;

  @override
  Widget build(BuildContext context) {
    final displayName = _valueOrFallback(
      result.displayName,
      fallback: 'Estudiante',
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _ValidatedPrivatePhoto(
              photoPath: result.photoPath,
              initials: _initials(displayName),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            _ResultDataRow(
              label: 'Número de control',
              value: _valueOrFallback(result.controlNumber),
            ),
            _ResultDataRow(
              label: 'Carrera',
              value:
                  result.careerId == null
                      ? 'No registrada'
                      : InstitutionalCareers.labelFor(result.careerId!),
            ),
            _ResultDataRow(
              label: 'Semestre',
              value:
                  result.semester == null
                      ? 'No registrado'
                      : '${result.semester}.º semestre',
            ),
            _ResultDataRow(
              label: 'Grupo',
              value: _valueOrFallback(result.groupId).toUpperCase(),
            ),
            _ResultDataRow(
              label: 'Validado',
              value: _formatValidationTime(result.validatedAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidatedPrivatePhoto extends StatefulWidget {
  const _ValidatedPrivatePhoto({
    required this.photoPath,
    required this.initials,
  });

  final String? photoPath;
  final String initials;

  @override
  State<_ValidatedPrivatePhoto> createState() => _ValidatedPrivatePhotoState();
}

class _ValidatedPrivatePhotoState extends State<_ValidatedPrivatePhoto> {
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant _ValidatedPrivatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.photoPath != widget.photoPath) {
      _loadPhoto();
    }
  }

  void _loadPhoto() {
    final path = widget.photoPath?.trim();

    if (path == null || path.isEmpty) {
      _signedUrlFuture = null;
      return;
    }

    _signedUrlFuture = context
        .read<StudentProfilePhotoRepository>()
        .createSignedUrl(path, expiresInSeconds: 600);
  }

  @override
  Widget build(BuildContext context) {
    final future = _signedUrlFuture;

    return Container(
      width: 132,
      height: 165,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF003B5C),
        borderRadius: BorderRadius.circular(22),
      ),
      child:
          future == null
              ? _ValidationPhotoFallback(initials: widget.initials)
              : FutureBuilder<String>(
                future: future,
                builder: (context, snapshot) {
                  final url = snapshot.data;

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  if (snapshot.hasError || url == null || url.isEmpty) {
                    return _ValidationPhotoFallback(initials: widget.initials);
                  }

                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder:
                        (context, error, stackTrace) =>
                            _ValidationPhotoFallback(initials: widget.initials),
                  );
                },
              ),
    );
  }
}

class _ValidationPhotoFallback extends StatelessWidget {
  const _ValidationPhotoFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InvalidStudentResult extends StatelessWidget {
  const _InvalidStudentResult({required this.result});

  final StudentIdQrValidationResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const Icon(Icons.qr_code_2_rounded, size: 72),
            const SizedBox(height: AppSpacing.md),
            Text(
              _validationReasonLabel(result.reason),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Solicita al estudiante que abra nuevamente '
              'el reverso de su identificación y genera un '
              'código actualizado.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDataRow extends StatelessWidget {
  const _ResultDataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationConnectionError extends StatelessWidget {
  const _ValidationConnectionError({
    required this.message,
    required this.onRetry,
    required this.onScanAnother,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onScanAnother;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onScanAnother,
                  child: const Text('Escanear otro'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorState extends StatelessWidget {
  const _ScannerErrorState({required this.error, required this.onRetry});

  final MobileScannerException error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xlg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'No fue posible acceder a la cámara.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Revisa el permiso de cámara en la '
                'configuración del dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.78)),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnauthorizedValidatorState extends StatelessWidget {
  const _UnauthorizedValidatorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 64),
            SizedBox(height: AppSpacing.md),
            Text(
              'No tienes permisos para validar '
              'identificaciones.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _validationReasonLabel(String? reason) {
  return switch (reason) {
    'invalid_format' => 'El código no pertenece a Conecta ITT.',
    'token_not_found' =>
      'El código no existe o no fue emitido por el servidor.',
    'token_revoked' => 'El código fue sustituido por uno más reciente.',
    'token_expired' => 'El código temporal ya expiró.',
    'profile_not_found' => 'No se encontró el perfil institucional.',
    'inactive_profile' => 'La cuenta institucional está inactiva.',
    'incomplete_profile' => 'El perfil institucional está incompleto.',
    'photo_not_approved' => 'La fotografía institucional no está aprobada.',
    'missing_control_number' => 'El perfil no tiene número de control.',
    _ => 'El código no pudo validarse.',
  };
}

String _valueOrFallback(String? value, {String fallback = 'No registrado'}) {
  final normalized = value?.trim();

  if (normalized == null || normalized.isEmpty) {
    return fallback;
  }

  return normalized;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList(growable: false);

  if (parts.isEmpty) {
    return 'E';
  }

  return parts.map((part) => part.substring(0, 1).toUpperCase()).join();
}

String _formatValidationTime(DateTime value) {
  final local = value.toLocal();

  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}
