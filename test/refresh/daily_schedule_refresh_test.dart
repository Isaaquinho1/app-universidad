import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:conecta_itt/academic_planner/models/class_session.dart';
import 'package:conecta_itt/academic_planner/models/scheduled_class.dart';
import 'package:conecta_itt/academic_planner/repositories/academic_account_scope.dart';
import 'package:conecta_itt/academic_planner/repositories/daily_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/repositories/weekly_schedule_repository.dart';
import 'package:conecta_itt/academic_planner/view/daily_schedule_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Schedule implements DailyScheduleRepository {
  final requests = <Completer<List<ScheduledClass>>>[];
  final weekdays = <int>[];

  @override
  Future<List<ScheduledClass>> getByWeekday(int weekday) {
    weekdays.add(weekday);
    final request = Completer<List<ScheduledClass>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Weekly implements WeeklyScheduleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Account implements AcademicAccountScope {
  _Account(this.dailySchedule);

  @override
  final DailyScheduleRepository dailySchedule;

  @override
  final WeeklyScheduleRepository weeklySchedule = _Weekly();

  @override
  Future<T> run<T>(Future<T> Function() operation) => operation();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ScheduledClass _class(String title) {
  final now = DateTime.now();
  return ScheduledClass(
    subject: AcademicSubject(
      id: 'subject', name: title, colorValue: 0xFF003B5C,
      createdAt: now, updatedAt: now,
    ),
    session: ClassSession(
      id: 'session', subjectId: 'subject', weekday: now.weekday,
      startMinutes: 480, endMinutes: 540, createdAt: now, updatedAt: now,
    ),
  );
}

Future<_Schedule> _open(WidgetTester tester, TargetPlatform platform) async {
  final repository = _Schedule();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      platform: platform,
      extensions: const <ThemeExtension<dynamic>>[AppColors.light],
    ),
    home: Scaffold(body: DailyScheduleView(account: _Account(repository))),
  ));
  repository.requests.single.complete([_class('Redes')]);
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform: drag keeps content and a single loading indicator', (
      tester,
    ) async {
      final repository = await _open(tester, platform);
      final weekday = repository.weekdays.single;
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(repository.requests, hasLength(2));
      expect(repository.weekdays.last, weekday);
      expect(find.text('Redes'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      } else {
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      }
      final pending = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      ).show();
      await tester.pump();
      expect(repository.requests, hasLength(2));
      repository.requests.last.complete([_class('Redes actualizadas')]);
      await tester.pumpAndSettle();
      await pending;
      expect(find.text('Redes actualizadas'), findsOneWidget);
      expect(find.text('Redes'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$platform: refresh failure exposes a retry action', (tester) async {
      final repository = await _open(tester, platform);
      final pending = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      ).show();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      repository.requests.last.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      await pending;
      expect(find.text('Reintentar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
