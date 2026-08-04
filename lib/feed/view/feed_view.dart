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
      appBar: AppBar(title: const Text('Publicaciones')),
      body: const AnnouncementCategoryFeed(),
    );
  }
}
