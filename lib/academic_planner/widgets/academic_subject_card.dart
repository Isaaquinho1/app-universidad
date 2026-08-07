import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/academic_planner/models/academic_subject.dart';
import 'package:flutter/material.dart';

enum AcademicSubjectAction { edit, archive, restore, delete }

class AcademicSubjectCard extends StatelessWidget {
  const AcademicSubjectCard({
    super.key,
    required this.subject,
    required this.onTap,
    required this.onAction,
  });

  final AcademicSubject subject;
  final VoidCallback onTap;
  final ValueChanged<AcademicSubjectAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final subjectColor = Color(subject.colorValue);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.background02,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.deactive.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 76,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.name,
                            style: AppTextStyle.bodyBold.copyWith(
                              fontSize: 17,
                              color:
                                  subject.isArchived
                                      ? colors.deactive
                                      : colors.active,
                            ),
                          ),
                        ),
                        if (subject.isArchived)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.background03,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Archivada',
                              style: AppTextStyle.body.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.deactive,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (subject.code != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subject.code!,
                        style: AppTextStyle.body.copyWith(
                          color: subjectColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: colors.deactive,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subject.teacherName ?? 'Docente sin asignar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.body.copyWith(
                              color: colors.deactive,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<AcademicSubjectAction>(
                tooltip: 'Opciones de materia',
                onSelected: onAction,
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: AcademicSubjectAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value:
                            subject.isArchived
                                ? AcademicSubjectAction.restore
                                : AcademicSubjectAction.archive,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            subject.isArchived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                          title: Text(
                            subject.isArchived ? 'Restaurar' : 'Archivar',
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: AcademicSubjectAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Eliminar'),
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
