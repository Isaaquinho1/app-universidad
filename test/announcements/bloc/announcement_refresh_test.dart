import 'dart:async';

import 'package:conecta_itt/announcements/bloc/announcement_bloc.dart';
import 'package:conecta_itt/announcements/models/models.dart';
import 'package:conecta_itt/announcements/repositories/repositories.dart';
import 'package:conecta_itt/institutional_profile/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements AnnouncementRepository {
  final streams = <StreamController<List<Announcement>>>[];
  Future<Map<String, AnnouncementReceipt>>? nextReceipts;

  @override
  Stream<List<Announcement>> watchAnnouncementsForProfile({
    required AppUserProfile profile,
    int limit = 100,
  }) {
    final stream = StreamController<List<Announcement>>();
    streams.add(stream);
    return stream.stream;
  }

  @override
  Future<Map<String, AnnouncementReceipt>> fetchReceiptsForAnnouncements({
    required Iterable<String> announcementIds,
    required String userUid,
  }) {
    final result = nextReceipts ?? Future.value(<String, AnnouncementReceipt>{});
    nextReceipts = null;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Assets implements PublicationAssetRepository {
  Future<Map<String, List<PublicationAsset>>>? nextAssets;

  @override
  Future<Map<String, List<PublicationAsset>>> fetchAssetsForPublications({
    required Iterable<String> publicationIds,
  }) {
    final result = nextAssets ?? Future.value(<String, List<PublicationAsset>>{});
    nextAssets = null;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _flushEvents() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Repository repository;
  late _Assets assets;
  late AnnouncementBloc bloc;

  setUp(() {
    repository = _Repository();
    assets = _Assets();
    bloc = AnnouncementBloc(
      repository: repository,
      assetRepository: assets,
      profile: const AppUserProfile(
        uid: 'student',
        role: AppUserRole.student,
        active: true,
        profileCompleted: true,
      ),
    );
  });

  tearDown(() async {
    if (!bloc.isClosed) await bloc.close();
    for (final controller in repository.streams) {
      await controller.close();
    }
  });

  test('refresh waits for receipts and assets after the feed response', () async {
    final receipts = Completer<Map<String, AnnouncementReceipt>>();
    final media = Completer<Map<String, List<PublicationAsset>>>();
    repository.nextReceipts = receipts.future;
    assets.nextAssets = media.future;
    var completed = false;
    final refresh = bloc.refresh().then((_) => completed = true);
    await _flushEvents();
    repository.streams.single.add(const []);
    await _flushEvents();
    expect(completed, isFalse);
    receipts.complete(const {});
    await _flushEvents();
    expect(completed, isFalse);
    media.complete(const {});
    await refresh;
    expect(bloc.state.status, AnnouncementsStatus.populated);
  });

  test('concurrent refresh calls share one request and Future', () async {
    final first = bloc.refresh();
    final second = bloc.refresh();
    expect(identical(first, second), isTrue);
    await _flushEvents();
    expect(repository.streams, hasLength(1));
    repository.streams.single.add(const []);
    await Future.wait([first, second]);
  });

  test('an unchanged empty feed completes without showing initial loading', () async {
    final first = bloc.refresh();
    await _flushEvents();
    repository.streams.last.add(const []);
    await first;
    final previous = bloc.state;
    final next = bloc.refresh();
    await _flushEvents();
    expect(bloc.state, same(previous));
    repository.streams.last.add(const []);
    await next;
    expect(bloc.state, same(previous));
  });

  test('repository failure completes the refresh with its error', () async {
    final refresh = bloc.refresh();
    final error = StateError('offline');
    final result = expectLater(refresh, throwsA(same(error)));
    await _flushEvents();
    repository.streams.single.addError(error, StackTrace.current);
    await result;
    expect(bloc.state.status, AnnouncementsStatus.failure);
  });

  test('asset failure is reported while retaining the existing state policy', () async {
    final media = Completer<Map<String, List<PublicationAsset>>>();
    assets.nextAssets = media.future;
    final refresh = bloc.refresh();
    final error = StateError('media unavailable');
    final result = expectLater(refresh, throwsA(same(error)));
    await _flushEvents();
    repository.streams.single.add(const []);
    await _flushEvents();
    media.completeError(error, StackTrace.current);
    await result;
    expect(bloc.state.status, AnnouncementsStatus.populated);
  });

  test('an early asset error is handled while receipts are pending', () async {
    final receipts = Completer<Map<String, AnnouncementReceipt>>();
    final media = Completer<Map<String, List<PublicationAsset>>>();
    repository.nextReceipts = receipts.future;
    assets.nextAssets = media.future;
    final refresh = bloc.refresh();
    final error = StateError('media failed first');
    var settled = false;
    final result = expectLater(refresh, throwsA(same(error)))
        .then((_) => settled = true);
    await _flushEvents();
    repository.streams.single.add(const []);
    await _flushEvents();
    media.completeError(error, StackTrace.current);
    await _flushEvents();
    expect(settled, isFalse);
    receipts.complete(const {});
    await result;
  });

  test('an older event cannot finish a newer refresh', () async {
    final oldMedia = Completer<Map<String, List<PublicationAsset>>>();
    assets.nextAssets = oldMedia.future;
    bloc.add(const AnnouncementsStarted());
    await _flushEvents();
    repository.streams.first.add(const []);
    await _flushEvents();
    var completed = false;
    final refresh = bloc.refresh().then((_) => completed = true);
    await _flushEvents();
    oldMedia.complete(const {});
    await _flushEvents();
    expect(completed, isFalse);
    repository.streams.last.add(const []);
    await refresh;
  });

  test('a stream that ends without a response settles with an error', () async {
    final refresh = bloc.refresh();
    final result = expectLater(refresh, throwsStateError);
    await _flushEvents();
    await repository.streams.single.close();
    await result;
  });

  test('closing immediately cannot create a late subscription', () async {
    final refresh = bloc.refresh();
    final result = expectLater(refresh, throwsStateError);
    await bloc.close();
    await result;
    expect(repository.streams, isEmpty);
  });

  test('closing the feed settles its pending refresh', () async {
    final refresh = bloc.refresh();
    final result = expectLater(refresh, throwsStateError);
    await _flushEvents();
    await bloc.close();
    await result;
  });
}
