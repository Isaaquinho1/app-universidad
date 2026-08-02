import 'package:analytics_repository/analytics_repository.dart';
import 'package:deep_link_client/deep_link_client.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_client/package_info_client.dart';
import 'package:persistent_storage/persistent_storage.dart';
import 'package:conecta_itt/announcements/announcements.dart';
import 'package:conecta_itt/common/utils/logger.dart';
import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:conecta_itt/main/bootstrap/bloc_observer_initializer.dart';
import 'package:conecta_itt/main/bootstrap/firebase_initializer.dart';
import 'package:conecta_itt/main/bootstrap/supabase_initializer.dart';
import 'package:conecta_itt/main/bootstrap/hydrated_storage_initializer.dart';
import 'package:conecta_itt/main/bootstrap/shared_preferences_initializer.dart';
import 'package:conecta_itt/main/bootstrap/package_info_initializer.dart';
import 'package:supabase_authentication_client/supabase_authentication_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:token_storage/token_storage.dart';
import 'package:user_repository/user_repository.dart';
import 'package:yx_scope/yx_scope.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart' hide Scope;

/// Public interface for the root application scope.
abstract class AppScope implements Scope {
  AnalyticsRepository get analyticsRepository;
  UserRepository get userRepository;
  AppUserProfileRepository get appUserProfileRepository;
  AcademicCatalogRepository get academicCatalogRepository;
  StudentProfilePhotoRepository get studentProfilePhotoRepository;
  AdminProfilePhotoRepository get adminProfilePhotoRepository;
  StudentIdQrRepository get studentIdQrRepository;
  AnnouncementRepository get announcementRepository;
  PublicationAssetRepository get publicationAssetRepository;
  SupabaseClient get supabaseClient;
}

/// Root scope container. Holds all long-living dependencies.
class AppScopeContainer extends ScopeContainer implements AppScope {
  AppScopeContainer({required bool dev});

  // Async initializers - first wave
  late final _sharedPreferencesInitializerDep = asyncDep(
    () => SharedPreferencesInitializer(),
  );
  late final _packageInfoInitializerDep = asyncDep(
    () => PackageInfoInitializer(),
  );
  late final _firebaseInitializerDep = asyncDep(() => FirebaseInitializer());
  late final _supabaseInitializerDep = asyncDep(() => SupabaseInitializer());

  // Async initializers - second wave
  late final _hydratedStorageInitializerDep = asyncDep(
    () => HydratedStorageInitializer(
      sharedPreferences: _sharedPreferencesInitializerDep.get.instance,
    ),
  );

  // Primitive deps / platform services
  late final _sharedPreferencesDep = dep(
    () => _sharedPreferencesInitializerDep.get.instance,
  );
  late final _packageInfoDep = dep(
    () => _packageInfoInitializerDep.get.instance,
  );
  late final _supabaseClientDep = dep(() => Supabase.instance.client);

  // Storage layer
  late final _persistentStorageDep = dep(
    () => PersistentStorage(sharedPreferences: _sharedPreferencesDep.get),
  );
  late final _tokenStorageDep = dep(() => InMemoryTokenStorage());

  // External service abstractions
  late final _deepLinkServiceDep = dep(
    () => DeepLinkService(deepLinkClient: DeepLinkClient()),
  );
  late final _packageInfoClientDep = dep(() {
    final packageInfo = _packageInfoDep.get;
    return PackageInfoClient(
      appName:
          kDebugMode ? '${packageInfo.appName} [DEV]' : packageInfo.appName,
      packageName: packageInfo.packageName,
      packageVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
  });

  // Auth
  late final _authenticationClientDep = dep(
    () => SupabaseAuthenticationClient(
      tokenStorage: _tokenStorageDep.get,
      supabaseAuth: _supabaseClientDep.get.auth,
    ),
  );

  // Repositories
  late final _userStorageDep = dep(
    () => UserStorage(storage: _persistentStorageDep.get),
  );
  late final _userRepositoryDep = dep(
    () => UserRepository(
      authenticationClient: _authenticationClientDep.get,
      packageInfoClient: _packageInfoClientDep.get,
      deepLinkService: _deepLinkServiceDep.get,
      storage: _userStorageDep.get,
    ),
  );
  late final _appUserProfileRepositoryDep = dep(
    () => AppUserProfileRepository(supabaseClient: _supabaseClientDep.get),
  );
  late final _academicCatalogRepositoryDep = dep(
    () => AcademicCatalogRepository(supabaseClient: _supabaseClientDep.get),
  );
  late final _studentProfilePhotoRepositoryDep = dep(
    () => StudentProfilePhotoRepository(supabaseClient: _supabaseClientDep.get),
  );
  late final _adminProfilePhotoRepositoryDep = dep(
    () => AdminProfilePhotoRepository(supabaseClient: _supabaseClientDep.get),
  );
  late final _studentIdQrRepositoryDep = dep(
    () => StudentIdQrRepository(supabaseClient: _supabaseClientDep.get),
  );
  late final _announcementRepositoryDep = dep(
    () => AnnouncementRepository(supabaseClient: _supabaseClientDep.get),
  );

  late final _publicationAssetRepositoryDep = dep(
    () => PublicationAssetRepository(supabaseClient: _supabaseClientDep.get),
  );
  late final _analyticsRepositoryDep = dep(() {
    try {
      return AnalyticsRepository(FirebaseAnalytics.instance);
    } catch (e, st) {
      logger.e('Analytics init failed: $e');
      Sentry.captureException(e, stackTrace: st);
      return const AnalyticsRepository();
    }
  });

  late final _blocObserverInitializerDep = asyncDep(
    () => BlocObserverInitializer(
      analyticsRepository: _analyticsRepositoryDep.get,
    ),
  );

  @override
  List<Set<AsyncDep>> get initializeQueue => [
    {_sharedPreferencesInitializerDep},
    {
      _packageInfoInitializerDep,
      _firebaseInitializerDep,
      _supabaseInitializerDep,
    },
    {_hydratedStorageInitializerDep},
    {_blocObserverInitializerDep},
  ];

  @override
  AnalyticsRepository get analyticsRepository => _analyticsRepositoryDep.get;
  @override
  UserRepository get userRepository => _userRepositoryDep.get;
  @override
  AppUserProfileRepository get appUserProfileRepository =>
      _appUserProfileRepositoryDep.get;
  @override
  AcademicCatalogRepository get academicCatalogRepository =>
      _academicCatalogRepositoryDep.get;
  @override
  StudentProfilePhotoRepository get studentProfilePhotoRepository =>
      _studentProfilePhotoRepositoryDep.get;
  @override
  AdminProfilePhotoRepository get adminProfilePhotoRepository =>
      _adminProfilePhotoRepositoryDep.get;
  @override
  StudentIdQrRepository get studentIdQrRepository =>
      _studentIdQrRepositoryDep.get;
  @override
  AnnouncementRepository get announcementRepository =>
      _announcementRepositoryDep.get;
  @override
  PublicationAssetRepository get publicationAssetRepository =>
      _publicationAssetRepositoryDep.get;
  @override
  SupabaseClient get supabaseClient => _supabaseClientDep.get;
}

/// Holder for the [AppScopeContainer].
class AppScopeHolder extends ScopeHolder<AppScopeContainer> {
  AppScopeHolder({this.dev = false});

  final bool dev;

  @override
  AppScopeContainer createContainer() => AppScopeContainer(dev: dev);
}
