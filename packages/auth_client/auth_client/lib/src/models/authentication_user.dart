import 'package:equatable/equatable.dart';

/// {@template authentication_user}
/// User model.
///
/// [AuthenticationUser.anonymous] represents an unauthenticated user.
/// {@endtemplate}
class AuthenticationUser extends Equatable {
  /// {@macro authentication_user}
  const AuthenticationUser({
    required this.id,
    this.email,
    this.name,
    this.photo,
    this.isNewUser = true,
    this.isPasswordRecovery = false,
  });

  /// The current user's email address.
  final String? email;

  /// The current user's id.
  final String id;

  /// The current user's name (display name).
  final String? name;

  /// URL for the current user's photo.
  final String? photo;

  /// Whether the current user is a first time user.
  final bool isNewUser;

  /// Whether the session is being used for password recovery.
  final bool isPasswordRecovery;

  /// Whether the current user is anonymous.
  bool get isAnonymous => this == anonymous;

  /// Anonymous user which represents an unauthenticated user.
  static const anonymous = AuthenticationUser(id: '');

  @override
  List<Object?> get props => [
    email,
    id,
    name,
    photo,
    isNewUser,
    isPasswordRecovery,
  ];
}
