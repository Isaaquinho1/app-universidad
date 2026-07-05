import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({
    super.key,
    required this.type,
    required this.date,
    required this.time,
  });

  final String type;
  final String date;
  final String time;

  bool get _isEntry {
    const legacyEntryType = '\u0412\u0445\u043e\u0434';
    return type == 'Entrada' || type == legacyEntryType;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final displayType = _isEntry ? 'Entrada' : type;

    return Card(
      color: colors.background02,
      child: Container(
        width: double.infinity,
        height: 80,
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.background03,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 24,
                height: 24,
                decoration: _isEntry
                    ? const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xff99db7e), Color(0xff6da95b)],
                        ),
                      )
                    : BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.colorful02,
                      ),
                alignment: Alignment.center,
                child: _isEntry
                    ? const FaIcon(FontAwesomeIcons.rightToBracket, size: 15)
                    : const FaIcon(FontAwesomeIcons.rightFromBracket, size: 15),
              ),
            ),
            const SizedBox(width: 55.50),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayType, style: AppTextStyle.bodyBold),
                Text(
                  '$date, $time',
                  style: AppTextStyle.captionL.copyWith(
                    color: _isEntry ? colors.colorful05 : colors.colorful02,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
