import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_storage/secure_storage.dart';
import 'package:storage/storage.dart';

class _FakeFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};

  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  bool failDeleteAll = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #read:
        if (failRead) {
          return Future<String?>.error(Exception('Error de lectura'));
        }
        final key = invocation.namedArguments[#key] as String;
        return Future<String?>.value(values[key]);

      case #write:
        if (failWrite) {
          return Future<void>.error(Exception('Error de escritura'));
        }
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        values[key] = value;
        return Future<void>.value();

      case #delete:
        if (failDelete) {
          return Future<void>.error(Exception('Error de eliminación'));
        }
        final key = invocation.namedArguments[#key] as String;
        values.remove(key);
        return Future<void>.value();

      case #deleteAll:
        if (failDeleteAll) {
          return Future<void>.error(Exception('Error de limpieza'));
        }
        values.clear();
        return Future<void>.value();
    }

    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('SecureStorage', () {
    late _FakeFlutterSecureStorage fake;
    late SecureStorage storage;

    setUp(() {
      fake = _FakeFlutterSecureStorage();
      storage = SecureStorage(fake);
    });

    test('devuelve null cuando la clave no existe', () async {
      expect(await storage.read(key: 'inexistente'), isNull);
    });

    test('guarda y recupera un valor', () async {
      await storage.write(key: 'materia', value: 'Matemáticas');

      expect(await storage.read(key: 'materia'), 'Matemáticas');
    });

    test('elimina una clave sin afectar las demás', () async {
      await storage.write(key: 'materia', value: 'Matemáticas');
      await storage.write(key: 'grupo', value: 'A');

      await storage.delete(key: 'materia');

      expect(await storage.read(key: 'materia'), isNull);
      expect(await storage.read(key: 'grupo'), 'A');
    });

    test('elimina todos los valores', () async {
      await storage.write(key: 'materia', value: 'Matemáticas');
      await storage.write(key: 'grupo', value: 'A');

      await storage.clear();

      expect(await storage.read(key: 'materia'), isNull);
      expect(await storage.read(key: 'grupo'), isNull);
    });

    test('convierte errores de lectura en StorageException', () async {
      fake.failRead = true;

      await expectLater(
        storage.read(key: 'materia'),
        throwsA(
          isA<StorageException>().having(
            (exception) => exception.error,
            'error original',
            isA<Exception>(),
          ),
        ),
      );
    });

    test('convierte errores de escritura en StorageException', () async {
      fake.failWrite = true;

      await expectLater(
        storage.write(key: 'materia', value: 'Matemáticas'),
        throwsA(isA<StorageException>()),
      );
    });

    test('convierte errores de eliminación en StorageException', () async {
      fake.failDelete = true;

      await expectLater(
        storage.delete(key: 'materia'),
        throwsA(isA<StorageException>()),
      );
    });

    test('convierte errores de limpieza en StorageException', () async {
      fake.failDeleteAll = true;

      await expectLater(
        storage.clear(),
        throwsA(isA<StorageException>()),
      );
    });
  });
}
