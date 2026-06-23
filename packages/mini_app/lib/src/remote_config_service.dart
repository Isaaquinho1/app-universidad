class RemoteConfigService {
  static Map<String, dynamic> _config = {};

  static void setConfig(Map<String, dynamic> config) {
    _config = config;
    print('Configuración remota establecida: $_config');
  }

  static dynamic getValue(String key) => _config[key];

  /// Comprueba si un módulo está habilitado.
  static bool isModuleEnabled(String moduleId) {
    // Forzamos la conversión a bool (si es null, devuelve false)
    return (_config['module_${moduleId}_enabled'] as bool?) ?? false;
  }

  /// Obtiene la versión requerida del módulo.
  static String? getModuleVersion(String moduleId) {
    // Forzamos la conversión a String
    return _config['module_${moduleId}_version'] as String?;
  }
}
