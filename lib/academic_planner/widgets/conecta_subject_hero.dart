import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:flutter/material.dart';

/// Shared visual identity for an academic subject during Hero transitions.
class ConectaSubjectHero extends StatelessWidget {
  /// Creates the shared subject identity surface.
  const ConectaSubjectHero({
    required this.subject,
    required this.color,
    super.key,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  /// Subject represented by the Hero.
  final AcademicSubject subject;

  /// Contextual subject color.
  final Color color;

  /// Optional supporting text.
  final String? subtitle;

  /// Optional trailing widget.
  final Widget? trailing;

  /// Whether a compact representation should be used.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Material(
      type: MaterialType.transparency,
      child: ConectaSurface(
        level:
            compact ? ConectaSurfaceLevel.raised : ConectaSurfaceLevel.floating,
        accent: color,
        borderRadius: BorderRadius.circular(
          compact ? ConectaRadius.card : ConectaRadius.floating,
        ),
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xlg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: ConectaMotion.emphasized,
              curve: ConectaCurves.emphasized,
              width: compact ? 44 : 58,
              height: compact ? 44 : 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(
                  compact ? ConectaRadius.control : ConectaRadius.card,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: compact ? 10 : 18,
                    offset: Offset(0, compact ? 3 : 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: color,
                size: compact ? 22 : 26,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.titleM.copyWith(
                      fontSize: compact ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: colors.active,
                      height: 1.15,
                    ),
                  ),
                  if (subject.teacherName != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subject.teacherName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.body.copyWith(color: colors.deactive),
                    ),
                  ],
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.captionL.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
