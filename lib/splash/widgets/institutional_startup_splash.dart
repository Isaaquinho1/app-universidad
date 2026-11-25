import 'package:conecta_itt/splash/view/institutional_splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Keeps the approved design and requests legible, transparent system bars.
class InstitutionalStartupSplash extends StatelessWidget {
  const InstitutionalStartupSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: const InstitutionalSplashPage(),
    );
  }
}

/// Warm the original assets before releasing the native first-frame snapshot.
Future<void> precacheInstitutionalSplash(BuildContext context) async {
  Future<void> loadCampus() async {
    Object? imageError;
    StackTrace? imageStack;
    await precacheImage(
      const AssetImage('assets/campus/campus_splash.jpg'),
      context,
      onError: (error, stack) {
        imageError = error;
        imageStack = stack;
      },
    );
    if (imageError != null) {
      Error.throwWithStackTrace(imageError!, imageStack ?? StackTrace.current);
    }
  }

  await Future.wait([
    loadCampus(),
    for (final asset in const [
      'assets/branding/institutional/sep_logo_2026.svg',
      'assets/branding/institutional/tecnm_logo.svg',
      'assets/branding/institutional/tlalpan_logo.svg',
    ])
      vg.loadPicture(SvgAssetLoader(asset), context).then((picture) {
        picture.picture.dispose();
      }),
  ]);
  // The mounted SvgPicture widgets share the encoded byte cache; let their
  // completed decodes paint before the engine receives its first Flutter frame.
  await WidgetsBinding.instance.endOfFrame;
}
