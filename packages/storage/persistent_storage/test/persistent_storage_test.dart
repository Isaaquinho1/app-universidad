import 'package:flutter_test/flutter_test.dart';
import 'package:persistent_storage/persistent_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
}
