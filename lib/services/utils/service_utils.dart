import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:conecta_itt/services/models/service_model.dart';

/// Utilities for working with services
class ServiceUtils {
  /// Navigate to a service based on its model
  static void navigateToService(BuildContext context, ServiceModel service) {
    if (service.isComingSoon) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(Icons.map_rounded),
            title: Text(service.title),
            content: Text('${service.title} estará disponible próximamente.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (service.isExternal) {
      if (service.url != null) {
        launchUrlString(service.url!, mode: LaunchMode.externalApplication);
      }
    } else {
      if (service.routePath != null) {
        context.go(service.routePath!);
      }
    }
  }

  /// Navigate to a community
  static void navigateToCommunity(CommunityModel community) {
    launchUrlString(community.url, mode: LaunchMode.externalApplication);
  }
}
