import 'package:conecta_itt/institutional_profile/models/app_user_profile.dart';
import 'package:conecta_itt/institutional_profile/models/app_user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Academic permissions by institutional role', () {
    for (final role in AppUserRole.values) {
      test('${role.value}: student academic consultation', () {
        final expected =
            role == AppUserRole.admin || role == AppUserRole.superAdmin;

        expect(role.canManageStudentAcademics, expected);
      });

      test('${role.value}: academic identity modification', () {
        expect(role.canEditStudentAcademics, role == AppUserRole.superAdmin);
      });

      test('${role.value}: academic offerings management', () {
        expect(role.canManageAcademicOfferings, role == AppUserRole.superAdmin);
      });
    }
  });

  group('Academic permissions by profile status', () {
    for (final role in AppUserRole.values) {
      for (final active in [true, false]) {
        final profile = AppUserProfile(
          uid: 'test-user',
          role: role,
          profileCompleted: true,
          active: active,
        );

        test('${role.value}, active=$active: consultation', () {
          expect(
            profile.canManageStudentAcademics,
            active &&
                (role == AppUserRole.admin || role == AppUserRole.superAdmin),
          );
        });

        test('${role.value}, active=$active: identity modification', () {
          expect(
            profile.canEditStudentAcademics,
            active && role == AppUserRole.superAdmin,
          );
        });

        test('${role.value}, active=$active: offerings management', () {
          expect(
            profile.canManageAcademicOfferings,
            active && role == AppUserRole.superAdmin,
          );
        });
      }
    }
  });
}
