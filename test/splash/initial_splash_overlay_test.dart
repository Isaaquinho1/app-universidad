import 'package:conecta_itt/splash/view/institutional_splash_page.dart';
import 'package:conecta_itt/splash/widgets/initial_splash_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first profile load preserves child and never repeats splash', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    var mounts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder:
              (context, value, child) =>
                  InitialSplashOverlay(ready: value, child: child!),
          child: _MountCounter(onMount: () => mounts++),
        ),
      ),
    );
    expect(find.byType(InstitutionalSplashPage), findsOneWidget);
    expect(mounts, 1);

    ready.value = true;
    await tester.pump();
    expect(find.byType(InstitutionalSplashPage), findsNothing);
    expect(find.text('Active router'), findsOneWidget);
    expect(mounts, 1);

    // A subsequent account change must use the existing account-change UI.
    ready.value = false;
    await tester.pump();
    expect(find.byType(InstitutionalSplashPage), findsNothing);
    expect(mounts, 1);
  });
}

class _MountCounter extends StatefulWidget {
  const _MountCounter({required this.onMount});
  final VoidCallback onMount;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const Text('Active router');
}
