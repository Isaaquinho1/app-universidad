part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginEmailChanged extends LoginEvent {
  const LoginEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

class LoginPasswordChanged extends LoginEvent {
  const LoginPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

class LoginPasswordVisibilityChanged extends LoginEvent {
  const LoginPasswordVisibilityChanged();
}

class LoginSubmitted extends LoginEvent with AnalyticsEventMixin {
  const LoginSubmitted();

  @override
  AnalyticsEvent get event => const AnalyticsEvent('LoginSubmitted');
}

class LoginBiometricAvailabilityRequested extends LoginEvent {
  const LoginBiometricAvailabilityRequested();
}

class LoginBiometricSubmitted extends LoginEvent with AnalyticsEventMixin {
  const LoginBiometricSubmitted();

  @override
  AnalyticsEvent get event => const AnalyticsEvent('LoginBiometricSubmitted');
}

class LoginBiometricEnrollmentAccepted extends LoginEvent {
  const LoginBiometricEnrollmentAccepted();
}

class LoginBiometricEnrollmentDeclined extends LoginEvent {
  const LoginBiometricEnrollmentDeclined();
}

class LoginBiometricEnrollmentHandled extends LoginEvent {
  const LoginBiometricEnrollmentHandled();
}

/// Legacy Magic Link event.
///
/// It remains temporarily while the old interface is being replaced.
class SendEmailLinkSubmitted extends LoginEvent with AnalyticsEventMixin {
  const SendEmailLinkSubmitted();

  @override
  AnalyticsEvent get event => const AnalyticsEvent('SendEmailLinkSubmitted');
}
