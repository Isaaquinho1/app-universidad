import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rtu_mirea_app/institutional_profile/models/models.dart';

/// Repository that manages institutional user profiles in Firestore.
class AppUserProfileRepository {
  /// Creates an [AppUserProfileRepository].
  const AppUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _db.collection('users');

  /// Returns the Firestore document reference for a user profile.
  DocumentReference<Map<String, dynamic>> userDocument(String uid) {
    return _usersCollection.doc(uid);
  }

  /// Watches the institutional profile for the provided [uid].
  Stream<AppUserProfile?> watchProfile(String uid) {
    if (uid.isEmpty) {
      return Stream.value(null);
    }

    return userDocument(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }

      return AppUserProfile.fromFirestore(snapshot);
    });
  }

  /// Fetches the institutional profile for the provided [uid].
  Future<AppUserProfile?> fetchProfile(String uid) async {
    if (uid.isEmpty) {
      return null;
    }

    final snapshot = await userDocument(uid).get();

    if (!snapshot.exists) {
      return null;
    }

    return AppUserProfile.fromFirestore(snapshot);
  }

  /// Creates a basic student profile if the user document does not exist.
  Future<AppUserProfile> ensureStudentProfile({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    final document = userDocument(uid);
    final snapshot = await document.get();

    if (snapshot.exists) {
      return AppUserProfile.fromFirestore(snapshot);
    }

    final data = <String, dynamic>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': AppUserRole.student.value,
      'careerId': null,
      'semester': null,
      'groupId': null,
      'controlNumber': null,
      'fcmTokens': <String, String>{},
      'profileCompleted': false,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await document.set(data);

    final createdSnapshot = await document.get();

    return AppUserProfile.fromFirestore(createdSnapshot);
  }

  /// Updates institutional profile fields for the provided [uid].
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? careerId,
    int? semester,
    String? groupId,
    String? controlNumber,
    bool? profileCompleted,
  }) async {
    final data = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (careerId != null) 'careerId': careerId,
      if (semester != null) 'semester': semester,
      if (groupId != null) 'groupId': groupId,
      if (controlNumber != null) 'controlNumber': controlNumber,
      if (profileCompleted != null) 'profileCompleted': profileCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await userDocument(uid).set(data, SetOptions(merge: true));
  }

  /// Updates the role of a user.
  ///
  /// This must only be called from trusted admin flows.
  Future<void> updateRole({
    required String uid,
    required AppUserRole role,
  }) async {
    await userDocument(uid).set({
      'role': role.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stores or updates a Firebase Cloud Messaging token for the user.
  Future<void> updateFcmToken({
    required String uid,
    required String deviceId,
    required String token,
  }) async {
    await userDocument(uid).set({
      'fcmTokens.$deviceId': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
