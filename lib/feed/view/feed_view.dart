import 'package:flutter/material.dart';
import 'package:conecta_itt/announcements/announcements.dart';

/// Main institutional feed for Conecta ITT.
///
/// Displays global institutional news and announcements segmented
/// for the authenticated profile.
class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color(0xFFF7F8FA),
      body: const AnnouncementCategoryFeed(),
    );
  }
}
