import 'package:flutter/material.dart';
import 'package:conecta_itt/announcements/announcements.dart';

/// Main institutional feed for Conecta ITT.
///
/// At this stage, the feed displays only segmented institutional
/// announcements backed by Supabase.
class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicados')),
      body: const AnnouncementCategoryFeed(),
    );
  }
}
