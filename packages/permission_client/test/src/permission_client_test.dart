import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_client/permission_client.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionClient', () {
    const channel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );

    late PermissionClient permissionClient;
    late List<MethodCall> calls;

    setUp(() {
      permissionClient = const PermissionClient();
      calls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);

            if (call.method == 'checkPermissionStatus') {
              return PermissionStatus.granted.index;
            }

            if (call.method == 'requestPermissions') {
              return <dynamic, dynamic>{
                for (final key in call.arguments as List<dynamic>)
                  key: PermissionStatus.granted.index,
              };
            }

            if (call.method == 'openAppSettings') {
              return true;
            }

            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Matcher permissionWasRequested(Permission permission) => contains(
      isA<MethodCall>()
          .having((call) => call.method, 'method', 'requestPermissions')
          .having(
            (call) => call.arguments,
            'arguments',
            contains(permission.value),
          ),
    );

    Matcher permissionWasChecked(Permission permission) => contains(
      isA<MethodCall>()
          .having((call) => call.method, 'method', 'checkPermissionStatus')
          .having(
            (call) => call.arguments,
            'arguments',
            equals(permission.value),
          ),
    );

    group('requestNotifications', () {
      test('calls correct method', () async {
        await permissionClient.requestNotifications();

        expect(calls, permissionWasRequested(Permission.notification));
      });
    });

    group('notificationsStatus', () {
      test('calls correct method', () async {
        await permissionClient.notificationsStatus();

        expect(calls, permissionWasChecked(Permission.notification));
      });
    });

    group('openPermissionSettings', () {
      test('calls correct method', () async {
        await permissionClient.openPermissionSettings();

        expect(
          calls,
          contains(
            isA<MethodCall>().having(
              (call) => call.method,
              'method',
              'openAppSettings',
            ),
          ),
        );
      });
    });
  });
}
