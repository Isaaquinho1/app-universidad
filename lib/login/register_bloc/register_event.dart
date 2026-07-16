part of 'register_bloc.dart';

abstract class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

class RegisterEmailChanged extends RegisterEvent {
  const RegisterEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

class RegisterPasswordChanged extends RegisterEvent {
  const RegisterPasswordChanged(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}

class RegisterPasswordConfirmationChanged extends RegisterEvent {
  const RegisterPasswordConfirmationChanged(this.passwordConfirmation);

  final String passwordConfirmation;

  @override
  List<Object?> get props => [passwordConfirmation];
}

class RegisterSubmitted extends RegisterEvent with AnalyticsEventMixin {
  const RegisterSubmitted();

  @override
  AnalyticsEvent get event => const AnalyticsEvent('RegisterSubmitted');
}
