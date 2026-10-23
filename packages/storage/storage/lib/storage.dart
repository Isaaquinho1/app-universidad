/// {@template storage_exception}
/// Excepción producida por un fallo de almacenamiento.
/// {@endtemplate}
class StorageException implements Exception {
  /// {@macro storage_exception}
  const StorageException(this.error);

  /// Error asociado.
  final Object error;
}

/// Interfaz para almacenamiento local de tipo clave-valor.
abstract class Storage {
  /// Devuelve el valor asociado a [key].
  /// Devuelve `null` cuando la clave no existe.
  /// Lanza [StorageException] si falla la lectura.
  Future<String?> read({required String key});

  /// Almacena de forma asíncrona el par [key] y [value].
  /// Lanza [StorageException] si falla la escritura.
  Future<void> write({required String key, required String value});

  /// Elimina de forma asíncrona el valor asociado a [key].
  /// Lanza [StorageException] si falla la eliminación.
  Future<void> delete({required String key});

  /// Elimina de forma asíncrona todos los valores almacenados.
  /// Lanza [StorageException] si falla la limpieza.
  Future<void> clear();
}
