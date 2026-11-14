import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Avisos académicos compatibles con Material y Cupertino.
abstract final class AcademicNotice {
  static void show(BuildContext context, {required String message}) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      final messenger = ScaffoldMessenger.maybeOf(context);

      if (messenger != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (overlayContext) => Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: CupertinoPopupSurface(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style:
                              CupertinoTheme.of(
                                overlayContext,
                              ).textTheme.textStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
    );

    overlay.insert(entry);

    unawaited(
      Future<void>.delayed(const Duration(seconds: 4), () {
        entry.remove();
        entry.dispose();
      }),
    );
  }
}
