import 'package:storage/storage.dart';
import 'package:test/test.dart';

void main() {
  group('StorageException', () {
    test('conserva la referencia al error original', () {
      final originalError = StateError('Fallo de almacenamiento');
      final exception = StorageException(originalError);

      expect(exception.error, same(originalError));
    });

    test('implementa Exception', () {
      final exception = StorageException(Exception('Error de lectura'));

      expect(exception, isA<Exception>());
    });
  });
}
