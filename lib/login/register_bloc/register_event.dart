part of 'register_bloc.dart';

abstract class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

class RegisterFullNameChanged extends RegisterEvent {
  const RegisterFullNameChanged(this.fullName);

  final String fullName;

  @override
  List<Object?> get props => [fullName];
}

class RegisterEmailChanged extends RegisterEvent {
  const RegisterEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

class RegisterCareerChanged extends RegisterEvent {
  const RegisterCareerChanged(this.careerId);

  final String? careerId;

  @override
  List<Object?> get props => [careerId];
}

class RegisterSemesterChanged extends RegisterEvent {
  const RegisterSemesterChanged(this.semester);

  final int? semester;

  @override
  List<Object?> get props => [semester];
}

class RegisterGroupChanged extends RegisterEvent {
  const RegisterGroupChanged(this.groupId);

  final String? groupId;

  @override
  List<Object?> get props => [groupId];
}

class RegisterTermsAcceptanceChanged extends RegisterEvent {
  const RegisterTermsAcceptanceChanged(this.accepted);

  final bool accepted;

  @override
  List<Object?> get props => [accepted];
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

class RegisterLegalDocumentsRequested extends RegisterEvent {
  const RegisterLegalDocumentsRequested();
}

class RegisterSubmitted extends RegisterEvent with AnalyticsEventMixin {
  const RegisterSubmitted();

  @override
  AnalyticsEvent get event => const AnalyticsEvent('RegisterSubmitted');
}
