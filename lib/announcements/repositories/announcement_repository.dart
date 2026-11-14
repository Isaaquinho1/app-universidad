import 'dart:async';

import 'package:conecta_itt/announcements/models/models.dart';
import 'package:conecta_itt/announcements/models/publication_expiration_policy.dart';
import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Resultado de una operación de guardado confirmada por Supabase.
///
/// La notificación es null para borradores.
typedef AnnouncementSaveResult =
    ({String id, Map<String, dynamic>? notification});

/// Repository that manages institutional announcements and user receipts.
class AnnouncementRepository {
  /// Creates an [AnnouncementRepository].
  const AnnouncementRepository({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient _supabaseClient;

  static const _announcementsTable = 'announcements';
  static const _receiptsTable = 'announcement_receipts';

  /// Watches published announcements for the authenticated profile.
  ///
  /// This performs an initial fetch and refreshes whenever the announcements
  /// table emits a realtime change. The RPC remains the source of truth for
  /// segmentation and authorization.
  Stream<List<Announcement>> watchAnnouncementsForProfile({
    required AppUserProfile profile,
    int limit = 100,
  }) {
    if (!profile.active) {
      return Stream.value(const []);
    }

    late final StreamController<List<Announcement>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? realtimeSubscription;

    Future<void> refresh() async {
      try {
        final announcements = await _fetchVisibleAnnouncements(limit: limit);

        if (!controller.isClosed) {
          controller.add(announcements);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<List<Announcement>>(
      onListen: () {
        unawaited(refresh());

        realtimeSubscription = _supabaseClient
            .from(_announcementsTable)
            .stream(primaryKey: const ['id'])
            .listen((_) => unawaited(refresh()), onError: controller.addError);
      },
      onCancel: () async {
        await realtimeSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Watches published announcements for the authenticated user.
  Stream<List<Announcement>> watchPublishedAnnouncements({int limit = 100}) {
    final user = _supabaseClient.auth.currentUser;

    if (user == null) {
      return Stream.value(const []);
    }

    return Stream.fromFuture(_fetchVisibleAnnouncements(limit: limit));
  }

  /// Fetches one visible announcement by its identifier.
  Future<Announcement?> fetchAnnouncement(String announcementId) async {
    if (announcementId.isEmpty) {
      return null;
    }

    final rows = await _fetchVisibleAnnouncements(limit: 500);

    for (final announcement in rows) {
      if (announcement.id == announcementId) {
        return announcement;
      }
    }

    return null;
  }

  /// Lists announcements available to administrators.
  Future<List<Announcement>> fetchAdminAnnouncements({
    AnnouncementStatus? status,
    int limit = 200,
  }) async {
    _requireAnnouncementManager();

    final response = await _supabaseClient.rpc(
      'get_admin_announcements',
      params: {'p_status': status?.value, 'p_limit': limit.clamp(1, 500)},
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => Announcement.fromSupabase(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  /// Watches administrative announcements and refreshes on changes.
  Stream<List<Announcement>> watchAdminAnnouncements({
    AnnouncementStatus? status,
    int limit = 200,
  }) {
    late final StreamController<List<Announcement>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? subscription;

    Future<void> refresh() async {
      try {
        final announcements = await fetchAdminAnnouncements(
          status: status,
          limit: limit,
        );

        if (!controller.isClosed) {
          controller.add(announcements);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      }
    }

    controller = StreamController<List<Announcement>>(
      onListen: () {
        unawaited(refresh());

        subscription = _supabaseClient
            .from(_announcementsTable)
            .stream(primaryKey: const ['id'])
            .listen((_) => unawaited(refresh()), onError: controller.addError);
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  /// Creates an announcement and its audience targets atomically.
  Future<AnnouncementSaveResult> createAnnouncement(
    Announcement announcement,
  ) async {
    _requireAnnouncementManager();

    final values = announcement.toSupabase();

    if (announcement.id.isNotEmpty) {
      values['id'] = announcement.id;
    }

    if (announcement.status == AnnouncementStatus.published &&
        announcement.publishedAt == null) {
      values['published_at'] = DateTime.now().toUtc().toIso8601String();
    }

    final target = announcement.target;

    final response = await _supabaseClient.rpc(
      'create_announcement_with_targets',
      params: {
        'p_announcement': values,
        'p_target': {
          'roles': target.roles
              .map((role) => role.value)
              .toList(growable: false),
          'career_ids': target.careerIds.toList(growable: false),
          'semesters': target.semesters.toList(growable: false),
          'group_ids': target.groupIds.toList(growable: false),
          'user_ids': target.userUids.toList(growable: false),
        },
      },
    );

    if (response is! String || response.isEmpty) {
      throw StateError(
        'The transactional announcement RPC did not return an identifier.',
      );
    }

    final notification =
        announcement.status == AnnouncementStatus.published
            ? await _notificationResultAfterSaved(response)
            : null;

    return (id: response, notification: notification);
  }

  /// Updates an announcement and its audience targets atomically.
  Future<AnnouncementSaveResult> updateAnnouncement(
    Announcement announcement,
  ) async {
    _requireAnnouncementManager();

    if (announcement.id.isEmpty) {
      throw ArgumentError.value(
        announcement.id,
        'announcement.id',
        'An announcement identifier is required.',
      );
    }

    final target = announcement.target;

    final response = await _supabaseClient.rpc(
      'update_announcement_with_targets',
      params: {
        'p_announcement_id': announcement.id,
        'p_announcement': {
          ...announcement.toSupabase(),
          'expected_content_version': announcement.contentVersion,
        },
        'p_target': {
          'roles': target.roles
              .map((role) => role.value)
              .toList(growable: false),
          'career_ids': target.careerIds.toList(growable: false),
          'semesters': target.semesters.toList(growable: false),
          'group_ids': target.groupIds.toList(growable: false),
          'user_ids': target.userUids.toList(growable: false),
        },
      },
    );

    if (response is! String ||
        response.isEmpty ||
        response != announcement.id) {
      throw StateError(
        'The transactional update RPC returned an invalid identifier.',
      );
    }

    final notification =
        announcement.status == AnnouncementStatus.published
            ? await _notificationResultAfterSaved(announcement.id)
            : null;

    return (id: announcement.id, notification: notification);
  }

  /// Resolves the recipients eligible for an announcement reminder.
  Future<AnnouncementReminderPreview> fetchAnnouncementReminderPreview({
    required String announcementId,
    required AnnouncementReminderCriterion criterion,
  }) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcementId);

    final response = await _supabaseClient.rpc(
      'get_announcement_reminder_recipients',
      params: {
        'p_announcement_id': announcementId,
        'p_criterion': criterion.value,
      },
    );

    if (response is! Map) {
      throw StateError(
        'The reminder recipients RPC returned an invalid response.',
      );
    }

    return AnnouncementReminderPreview.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  /// Sends a segmented reminder to eligible announcement recipients.
  Future<Map<String, dynamic>> sendAnnouncementReminder({
    required String announcementId,
    required AnnouncementReminderCriterion criterion,
  }) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcementId);

    final requestKey = const Uuid().v4();

    final response = await _supabaseClient.functions.invoke(
      'send-announcement-reminder',
      body: {
        'announcement_id': announcementId,
        'criterion': criterion.value,
        'request_key': requestKey,
      },
    );

    final data = response.data;

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        'The reminder function returned HTTP ${response.status}: $data',
      );
    }

    if (data is! Map) {
      throw StateError('The reminder function returned an invalid response.');
    }

    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  /// Sends the FCM notification for one published announcement version.
  Future<Map<String, dynamic>> sendAnnouncementNotification(
    String announcementId,
  ) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcementId);

    final response = await _supabaseClient.functions.invoke(
      'send-announcement-notification',
      body: {'announcement_id': announcementId},
    );

    final data = response.data;

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        'The notification function returned HTTP ${response.status}: $data',
      );
    }

    if (data is! Map) {
      throw StateError(
        'The notification function returned an invalid response.',
      );
    }

    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  /// Valida FCM sin confundir su resultado con el guardado.
  Future<Map<String, dynamic>> _notificationResultAfterSaved(
    String announcementId,
  ) async {
    // La publicación ya fue confirmada por Supabase.
    // Un fallo posterior de FCM no debe presentarse como
    // un fallo de persistencia.
    try {
      final notification = await sendAnnouncementNotification(announcementId);

      // HTTP 2xx no basta para confirmar el resultado de FCM.
      // La Edge Function debe devolver un despacho identificable
      // y contadores completos, enteros y no negativos.
      const countFields = [
        'audience_count',
        'token_count',
        'sent_count',
        'failed_count',
        'no_token_count',
        'invalid_token_count',
      ];

      final dispatchId = notification['dispatch_id'];

      final validDispatch =
          dispatchId is String && dispatchId.trim().isNotEmpty;

      final validCounts = countFields.every((field) {
        final value = notification[field];
        return value is int && value >= 0;
      });

      if (!validDispatch || !validCounts) {
        throw const FormatException(
          'Respuesta de notificaciones incompleta o inválida.',
        );
      }

      final audienceCount = notification['audience_count'] as int;
      final tokenCount = notification['token_count'] as int;
      final sentCount = notification['sent_count'] as int;
      final failedCount = notification['failed_count'] as int;
      final noTokenCount = notification['no_token_count'] as int;
      final invalidTokenCount = notification['invalid_token_count'] as int;

      if (sentCount + failedCount != tokenCount ||
          invalidTokenCount > failedCount ||
          noTokenCount > audienceCount) {
        throw const FormatException(
          'Las métricas del despacho FCM son inconsistentes.',
        );
      }

      return {
        ...notification,
        'publication_saved': true,
        'notification_issue': false,
      };
    } catch (error) {
      return {
        'publication_saved': true,
        'notification_issue': true,
        'notification_error': error.toString(),
      };
    }
  }

  /// Publishes an announcement and sends its segmented notification.
  Future<Map<String, dynamic>> publishAnnouncement(
    Announcement announcement,
  ) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcement.id);

    if (announcement.status != AnnouncementStatus.draft &&
        announcement.status != AnnouncementStatus.scheduled) {
      throw StateError(
        'Solo se pueden publicar borradores o publicaciones programadas.',
      );
    }

    final now = DateTime.now().toUtc();

    final expiration =
        announcement.expiresAt ??
        PublicationExpirationPolicy.defaultExpiration(
          contentType: announcement.contentType,
          publishedAt: now,
        );

    if (!expiration.isAfter(now)) {
      throw StateError(
        'La fecha de vencimiento debe ser posterior a la publicación.',
      );
    }

    final updatedRows = await _supabaseClient
        .from(_announcementsTable)
        .update({
          'status': AnnouncementStatus.published.value,
          'published_at': now.toIso8601String(),
          'expires_at': expiration.toUtc().toIso8601String(),
        })
        .eq('id', announcement.id)
        .eq('status', announcement.status.value)
        .eq('updated_at', announcement.updatedAt.toUtc().toIso8601String())
        .select('id');

    if (updatedRows.length != 1) {
      throw StateError(
        'La publicación cambió o ya fue publicada. '
        'Actualiza el listado antes de intentarlo nuevamente.',
      );
    }

    return _notificationResultAfterSaved(announcement.id);
  }

  /// Requests safe deletion through the authorized Edge Function.
  Future<Map<String, dynamic>> deleteUnpublishedDraft(
    String publicationId,
  ) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(publicationId);

    final response = await _supabaseClient.functions.invoke(
      'delete-unpublished-draft',
      body: {'publication_id': publicationId},
    );

    final data = response.data;

    if (data is! Map) {
      throw StateError(
        'El servidor no devolvió un resultado válido de eliminación.',
      );
    }

    final result = Map<String, dynamic>.from(data);

    final matchesPublication = result['publication_id'] == publicationId;

    final deletedNow = result['deleted'] == true;
    final cleanupComplete = result['storage_cleanup_complete'] == true;
    final retryRequired = result['retry_required'] == true;

    if (!matchesPublication ||
        (!deletedNow && !cleanupComplete && !retryRequired)) {
      throw StateError(
        'El servidor no confirmó un resultado válido '
        'para este borrador.',
      );
    }

    return result;
  }

  /// Archives an announcement.
  Future<void> archiveAnnouncement(String announcementId) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcementId);

    await _supabaseClient
        .from(_announcementsTable)
        .update({'status': AnnouncementStatus.archived.value})
        .eq('id', announcementId);
  }

  /// Watches the authenticated user's receipt.
  Stream<AnnouncementReceipt?> watchReceipt({
    required String announcementId,
    required String userUid,
  }) {
    if (announcementId.isEmpty || userUid.isEmpty) {
      return Stream.value(null);
    }

    _validateCurrentUser(userUid);

    return _supabaseClient
        .from(_receiptsTable)
        .stream(primaryKey: const ['announcement_id', 'user_id'])
        .eq('announcement_id', announcementId)
        .map((rows) {
          for (final row in rows) {
            if (row['user_id'] == userUid) {
              return AnnouncementReceipt.fromSupabase(row);
            }
          }

          return null;
        });
  }

  /// Fetches the authenticated user's receipt.
  Future<AnnouncementReceipt?> fetchReceipt({
    required String announcementId,
    required String userUid,
  }) async {
    if (announcementId.isEmpty || userUid.isEmpty) {
      return null;
    }

    _validateCurrentUser(userUid);

    final row =
        await _supabaseClient
            .from(_receiptsTable)
            .select()
            .eq('announcement_id', announcementId)
            .eq('user_id', userUid)
            .maybeSingle();

    if (row == null) {
      return null;
    }

    return AnnouncementReceipt.fromSupabase(row);
  }

  /// Fetches the authenticated user's receipts for several announcements.
  Future<Map<String, AnnouncementReceipt>> fetchReceiptsForAnnouncements({
    required Iterable<String> announcementIds,
    required String userUid,
  }) async {
    final ids = announcementIds
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty || userUid.isEmpty) {
      return const {};
    }

    _validateCurrentUser(userUid);

    final rows = await _supabaseClient
        .from(_receiptsTable)
        .select()
        .eq('user_id', userUid)
        .inFilter('announcement_id', ids);

    final receipts = <String, AnnouncementReceipt>{};

    for (final row in rows) {
      final announcementId = row['announcement_id'] as String?;

      if (announcementId == null || announcementId.isEmpty) {
        continue;
      }

      receipts[announcementId] = AnnouncementReceipt.fromSupabase(row);
    }

    return receipts;
  }

  /// Advances a receipt without allowing status regression.
  Future<void> updateReceiptStatus({
    required String announcementId,
    required String userUid,
    required AnnouncementReceiptStatus status,
  }) async {
    if (announcementId.isEmpty || userUid.isEmpty) {
      throw ArgumentError('Both announcementId and userUid are required.');
    }

    _validateCurrentUser(userUid);

    await _supabaseClient.rpc(
      'advance_announcement_receipt',
      params: {'p_announcement_id': announcementId, 'p_status': status.value},
    );
  }

  Future<List<Announcement>> _fetchVisibleAnnouncements({
    required int limit,
  }) async {
    final response = await _supabaseClient.rpc(
      'get_visible_announcements',
      params: {'p_limit': limit.clamp(1, 500)},
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => Announcement.fromSupabase(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  /// Fetches server-side FCM dispatch metrics for one announcement.
  Future<AnnouncementNotificationMetrics> fetchAnnouncementNotificationMetrics(
    String announcementId,
  ) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcementId);

    final response = await _supabaseClient.rpc(
      'get_announcement_notification_metrics',
      params: {'p_announcement_id': announcementId},
    );

    if (response is! Map) {
      throw StateError(
        'The announcement notification metrics RPC returned '
        'an invalid response.',
      );
    }

    return AnnouncementNotificationMetrics.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  /// Fetches recipient metrics for one institutional announcement.
  Future<AnnouncementResults> fetchAnnouncementResults(
    String announcementId,
  ) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcementId);

    final response = await _supabaseClient.rpc(
      'get_announcement_results',
      params: {'p_announcement_id': announcementId},
    );

    if (response is! Map) {
      throw StateError(
        'The announcement results RPC returned an invalid response.',
      );
    }

    return AnnouncementResults.fromJson(
      response.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  /// Fetches one announcement from the administrative collection.
  Future<Announcement?> fetchAdminAnnouncement(String announcementId) async {
    _requireAnnouncementManager();
    _validateAnnouncementId(announcementId);

    final announcements = await fetchAdminAnnouncements(limit: 500);

    for (final announcement in announcements) {
      if (announcement.id == announcementId) {
        return announcement;
      }
    }

    return null;
  }

  /// Resolves direct recipient identifiers into active profile data.
  Future<List<AnnouncementRecipient>> fetchRecipientsByIds(
    Iterable<String> userUids,
  ) async {
    _requireAnnouncementManager();

    final ids = userUids
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (ids.isEmpty) {
      return const [];
    }

    final response = await _supabaseClient.rpc(
      'get_announcement_recipients_by_ids',
      params: {'p_user_ids': ids},
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => AnnouncementRecipient.fromSupabase(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((recipient) => recipient.uid.isNotEmpty)
        .toList(growable: false);
  }

  /// Searches active profiles for direct announcement recipients.
  Future<List<AnnouncementRecipient>> searchRecipients({
    required String query,
    int limit = 20,
  }) async {
    _requireAnnouncementManager();

    final normalizedQuery = query.trim();

    if (normalizedQuery.length < 2) {
      return const [];
    }

    final response = await _supabaseClient.rpc(
      'search_announcement_recipients',
      params: {'p_query': normalizedQuery, 'p_limit': limit.clamp(1, 50)},
    );

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map>()
        .map(
          (row) => AnnouncementRecipient.fromSupabase(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((recipient) => recipient.uid.isNotEmpty)
        .toList(growable: false);
  }

  void _requireAnnouncementManager() {
    final user = _supabaseClient.auth.currentUser;

    if (user == null) {
      throw StateError('An authenticated Supabase user is required.');
    }
  }

  void _validateCurrentUser(String uid) {
    final user = _supabaseClient.auth.currentUser;

    if (user == null || user.id != uid) {
      throw StateError(
        'The authenticated user cannot access another user receipt.',
      );
    }
  }

  static void _validateAnnouncementId(String announcementId) {
    if (announcementId.isEmpty) {
      throw ArgumentError.value(
        announcementId,
        'announcementId',
        'An announcement identifier is required.',
      );
    }
  }
}
