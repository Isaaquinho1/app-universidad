import 'package:flutter_test/flutter_test.dart';
import 'package:persistent_storage/persistent_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage/storage.dart';

class _FailingSharedPreferences implements SharedPreferences {
  @override
  String? getString(String key) {
    throw Exception('Fallo simulado de lectura');
  }

  @override
  Future<bool> setString(String key, String value) async {
    throw Exception('Fallo simulado de escritura');
  }

  @override
  Future<bool> remove(String key) async {
    throw Exception('Fallo simulado de eliminación');
  }

  @override
  Future<bool> clear() async {
    throw Exception('Fallo simulado de limpieza');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PersistentStorage', () {
    test('devuelve null cuando la clave no existe', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = PersistentStorage(sharedPreferences: preferences);

      final result = await storage.read(key: 'inexistente');

      expect(result, isNull);
    });

    test('guarda y recupera un valor', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = PersistentStorage(sharedPreferences: preferences);

      await storage.write(key: 'materia', value: 'Matemáticas');

      expect(await storage.read(key: 'materia'), 'Matemáticas');
    });

    test('elimina un valor sin afectar los demás', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = PersistentStorage(sharedPreferences: preferences);

      await storage.write(key: 'materia', value: 'Matemáticas');
      await storage.write(key: 'grupo', value: 'A');

      await storage.delete(key: 'materia');

      expect(await storage.read(key: 'materia'), isNull);
      expect(await storage.read(key: 'grupo'), 'A');
    });

    test('elimina todos los valores almacenados', () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = PersistentStorage(sharedPreferences: preferences);

      await storage.write(key: 'materia', value: 'Matemáticas');
      await storage.write(key: 'grupo', value: 'A');

      await storage.clear();

      expect(await storage.read(key: 'materia'), isNull);
      expect(await storage.read(key: 'grupo'), isNull);
    });

    group('manejo de excepciones', () {
      late PersistentStorage failingStorage;

      setUp(() {
        failingStorage = PersistentStorage(
          sharedPreferences: _FailingSharedPreferences(),
        );
      });

      test('convierte errores de lectura en StorageException', () async {
        await expectLater(
          failingStorage.read(key: 'materia'),
          throwsA(isA<StorageException>()),
        );
      });

      test('convierte errores de escritura en StorageException', () async {
        await expectLater(
          failingStorage.write(key: 'materia', value: 'Matemáticas'),
          throwsA(isA<StorageException>()),
        );
      });

      test('convierte errores de eliminación en StorageException', () async {
        await expectLater(
          failingStorage.delete(key: 'materia'),
          throwsA(isA<StorageException>()),
        );
      });

      test('convierte errores de limpieza en StorageException', () async {
        await expectLater(
          failingStorage.clear(),
          throwsA(isA<StorageException>()),
        );
      });
    });
  });
}
