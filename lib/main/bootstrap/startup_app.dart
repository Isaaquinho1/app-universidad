import 'dart:async';

import 'package:conecta_itt/splash/widgets/institutional_startup_splash.dart';
import 'package:flutter/material.dart';

/// Shows the approved Flutter splash while the application scope initializes.
/// The builder runs once; only an explicit retry starts another attempt.
class StartupApp extends StatefulWidget {
  const StartupApp({
    required this.initialize,
    required this.onError,
    this.prepareSplash = precacheInstitutionalSplash,
    this.onSplashReady,
    super.key,
  });

  final Future<Widget> Function() initialize;
  final void Function(Object error, StackTrace stackTrace) onError;
  final Future<void> Function(BuildContext context) prepareSplash;
  final VoidCallback? onSplashReady;

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  Widget? _app;
  bool _loading = true;
  bool _splashReadyReported = false;

  @override
  void initState() {
    super.initState();
    // Present the first Flutter frame before starting platform initialization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepareAndInitialize());
    });
  }

  void _reportSplashReady() {
    if (_splashReadyReported) return;
    _splashReadyReported = true;
    widget.onSplashReady?.call();
  }

  Future<void> _prepareAndInitialize() async {
    try {
      await widget.prepareSplash(context);
      if (!mounted) return;
      _reportSplashReady();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_initialize());
      });
      WidgetsBinding.instance.scheduleFrame();
    } catch (error, stackTrace) {
      widget.onError(error, stackTrace);
      if (mounted) setState(() => _loading = false);
      _reportSplashReady();
    }
  }

  @override
  void dispose() {
    // Balance bootstrap's first-frame deferral even if startup is unmounted.
    _reportSplashReady();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final app = await widget.initialize();
      if (mounted) setState(() => _app = app);
    } catch (error, stackTrace) {
      widget.onError(error, stackTrace);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _retry() {
    if (_loading) return;
    setState(() => _loading = true);
    unawaited(_prepareAndInitialize());
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conecta ITT',
      // Leave the platform's launch URI for the real router after startup.
      initialRoute: '/',
      home:
          _loading
              ? const InstitutionalStartupSplash()
              : Scaffold(
                backgroundColor: const Color(0xFF003B5C),
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No se pudo iniciar Conecta ITT.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _retry,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}
