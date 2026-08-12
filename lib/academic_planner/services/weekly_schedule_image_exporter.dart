import 'dart:io';
import 'dart:ui' as ui;

import 'package:conecta_itt/academic_planner/models/scheduled_class.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Generates a high-resolution PNG representation of the student's
/// weekly schedule suitable for sharing through external applications.
final class WeeklyScheduleImageExporter {
  const WeeklyScheduleImageExporter();

  static const _width = 1440.0;
  static const _horizontalPadding = 88.0;
  static const _topPadding = 82.0;
  static const _bottomPadding = 82.0;

  static const _dayHeaderHeight = 78.0;
  static const _classCardHeight = 142.0;
  static const _classGap = 18.0;
  static const _dayGap = 34.0;

  static const _weekdayLabels = <int, String>{
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  Future<File> export({
    required Map<int, List<ScheduledClass>> week,
    required String Function(int minutes) formatMinutes,
  }) async {
    final visibleDays = <int>[];

    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final classes = week[weekday] ?? const <ScheduledClass>[];
      if (classes.isNotEmpty) {
        visibleDays.add(weekday);
      }
    }

    final totalClasses = visibleDays.fold<int>(
      0,
      (total, weekday) =>
          total + (week[weekday] ?? const <ScheduledClass>[]).length,
    );

    final height = _calculateHeight(
      visibleDaysCount: visibleDays.length,
      totalClasses: totalClasses,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, _width, height));

    _paintBackground(canvas, height);

    var y = _topPadding;

    y = _paintHeader(canvas: canvas, y: y, totalClasses: totalClasses);

    y += 52;

    for (final weekday in visibleDays) {
      final classes = week[weekday] ?? const <ScheduledClass>[];

      y = _paintDay(
        canvas: canvas,
        y: y,
        weekday: weekday,
        classes: classes,
        formatMinutes: formatMinutes,
      );

      y += _dayGap;
    }

    _paintFooter(canvas: canvas, y: height - _bottomPadding + 8);

    final picture = recorder.endRecording();

    final image = await picture.toImage(_width.round(), height.round());

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('No fue posible codificar la imagen del horario.');
    }

    final directory = await getTemporaryDirectory();

    final file = File('${directory.path}/conecta_itt_horario_semanal.png');

    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    return file;
  }

  double _calculateHeight({
    required int visibleDaysCount,
    required int totalClasses,
  }) {
    const headerHeight = 210.0;
    const footerSpace = 100.0;

    return _topPadding +
        headerHeight +
        (visibleDaysCount * _dayHeaderHeight) +
        (totalClasses * _classCardHeight) +
        (totalClasses * _classGap) +
        (visibleDaysCount * _dayGap) +
        footerSpace +
        _bottomPadding;
  }

  void _paintBackground(Canvas canvas, double height) {
    final background = Paint()..color = const Color(0xFFF5F7FB);

    canvas.drawRect(Rect.fromLTWH(0, 0, _width, height), background);

    final accent =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF0067FF), Color(0xFF5B8CFF)],
          ).createShader(const Rect.fromLTWH(0, 0, _width, 18));

    canvas.drawRect(const Rect.fromLTWH(0, 0, _width, 18), accent);
  }

  double _paintHeader({
    required Canvas canvas,
    required double y,
    required int totalClasses,
  }) {
    final labelStyle = const TextStyle(
      color: Color(0xFF0067FF),
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
    );

    _paintText(
      canvas,
      text: 'CONECTA ITT',
      offset: Offset(_horizontalPadding, y),
      style: labelStyle,
    );

    y += 54;

    _paintText(
      canvas,
      text: 'Mi horario semanal',
      offset: Offset(_horizontalPadding, y),
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 62,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    );

    y += 82;

    _paintText(
      canvas,
      text:
          '$totalClasses ${totalClasses == 1 ? 'sesión programada' : 'sesiones programadas'}',
      offset: Offset(_horizontalPadding, y),
      style: const TextStyle(
        color: Color(0xFF667085),
        fontSize: 28,
        fontWeight: FontWeight.w500,
      ),
    );

    return y + 42;
  }

  double _paintDay({
    required Canvas canvas,
    required double y,
    required int weekday,
    required List<ScheduledClass> classes,
    required String Function(int minutes) formatMinutes,
  }) {
    final contentWidth = _width - (_horizontalPadding * 2);

    final headerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(_horizontalPadding, y, contentWidth, _dayHeaderHeight),
      const Radius.circular(24),
    );

    canvas.drawRRect(headerRect, Paint()..color = const Color(0xFFE9F1FF));

    _paintText(
      canvas,
      text: _weekdayLabels[weekday] ?? 'Día',
      offset: Offset(_horizontalPadding + 28, y + 21),
      style: const TextStyle(
        color: Color(0xFF174EA6),
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
    );

    final countText =
        '${classes.length} ${classes.length == 1 ? 'clase' : 'clases'}';

    final countPainter = _textPainter(
      text: countText,
      style: const TextStyle(
        color: Color(0xFF5B6B82),
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    )..layout();

    countPainter.paint(
      canvas,
      Offset(_width - _horizontalPadding - 28 - countPainter.width, y + 25),
    );

    y += _dayHeaderHeight + 18;

    for (final item in classes) {
      y = _paintClassCard(
        canvas: canvas,
        y: y,
        item: item,
        formatMinutes: formatMinutes,
      );

      y += _classGap;
    }

    return y;
  }

  double _paintClassCard({
    required Canvas canvas,
    required double y,
    required ScheduledClass item,
    required String Function(int minutes) formatMinutes,
  }) {
    final contentWidth = _width - (_horizontalPadding * 2);
    final subjectColor = Color(item.subject.colorValue);

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(_horizontalPadding, y, contentWidth, _classCardHeight),
      const Radius.circular(28),
    );

    canvas.drawRRect(cardRect, Paint()..color = Colors.white);

    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = const Color(0x14000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final railRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(_horizontalPadding + 20, y + 22, 10, _classCardHeight - 44),
      const Radius.circular(999),
    );

    canvas.drawRRect(railRect, Paint()..color = subjectColor);

    final contentX = _horizontalPadding + 56;

    _paintText(
      canvas,
      text: item.subject.name,
      offset: Offset(contentX, y + 22),
      style: const TextStyle(
        color: Color(0xFF172033),
        fontSize: 31,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: contentWidth - 100,
      maxLines: 1,
    );

    final start = formatMinutes(item.startMinutes);
    final end = formatMinutes(item.endMinutes);

    _paintText(
      canvas,
      text: '$start – $end',
      offset: Offset(contentX, y + 67),
      style: TextStyle(
        color: subjectColor,
        fontSize: 25,
        fontWeight: FontWeight.w700,
      ),
    );

    final location = [
      item.session.building,
      item.session.room,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    final teacher = item.subject.teacherName;

    final details = <String>[
      if (teacher != null && teacher.trim().isNotEmpty) teacher.trim(),
      if (location.isNotEmpty) location,
    ];

    if (details.isNotEmpty) {
      _paintText(
        canvas,
        text: details.join('   •   '),
        offset: Offset(contentX, y + 103),
        style: const TextStyle(
          color: Color(0xFF667085),
          fontSize: 21,
          fontWeight: FontWeight.w500,
        ),
        maxWidth: contentWidth - 100,
        maxLines: 1,
      );
    }

    return y + _classCardHeight;
  }

  void _paintFooter({required Canvas canvas, required double y}) {
    final text = 'Compartido desde Conecta ITT';

    final painter = _textPainter(
      text: text,
      style: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
    )..layout();

    painter.paint(canvas, Offset((_width - painter.width) / 2, y));
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required TextStyle style,
    double? maxWidth,
    int? maxLines,
  }) {
    final painter = _textPainter(text: text, style: style, maxLines: maxLines);

    painter.layout(maxWidth: maxWidth ?? double.infinity);

    painter.paint(canvas, offset);
  }

  TextPainter _textPainter({
    required String text,
    required TextStyle style,
    int? maxLines,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    );
  }
}
