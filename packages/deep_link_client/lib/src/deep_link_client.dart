import 'package:app_links/app_links.dart';

/// {@template deep_link_client}
/// A client for handling deep links.
/// {@endtemplate}
class DeepLinkClient {
  /// {@macro deep_link_client}
  DeepLinkClient({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  /// A stream of deep links received while the app is running.
  Stream<Uri> get deepLinkStream => _appLinks.uriLinkStream;

  /// Returns the initial link, or null when launched normally.
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();
}
