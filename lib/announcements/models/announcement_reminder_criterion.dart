enum AnnouncementReminderCriterion {
  pending('pending'),
  edited('edited'),
  notSeen('not_seen'),
  notRead('not_read'),
  notConfirmed('not_confirmed');

  const AnnouncementReminderCriterion(this.value);

  final String value;
}
