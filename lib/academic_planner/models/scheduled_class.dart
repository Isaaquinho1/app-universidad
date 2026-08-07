import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';

class ScheduledClass {
  const ScheduledClass({required this.subject, required this.session});

  final AcademicSubject subject;
  final ClassSession session;

  int get startMinutes => session.startMinutes;
  int get endMinutes => session.endMinutes;
}
