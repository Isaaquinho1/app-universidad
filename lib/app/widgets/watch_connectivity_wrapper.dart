import 'package:flutter/widgets.dart';

class WatchConnectivityWrapper extends StatelessWidget {
  const WatchConnectivityWrapper({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
