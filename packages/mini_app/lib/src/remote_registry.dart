import 'dart:convert';

class ModuleInfo {
  ModuleInfo({
    required this.id,
    required this.name,
    required this.author,
    required this.version,
    required this.enabled,
    this.updateUrl,
  });

  factory ModuleInfo.fromJson(Map<String, dynamic> json) {
    return ModuleInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      author: json['author'] as String,
      version: json['version'] as String,
      enabled: json['enabled'] as bool,
      updateUrl: json['updateUrl'] as String?,
    );
  }
  final String id;
  final String name;
  final String author;
  final String version;
  final bool enabled;
  final String? updateUrl;
}

/// Simulación de solicitud al registro remoto de módulos.
/// Aquí puedes reemplazarlo con una solicitud http real a un archivo en GitHub.
Future<List<ModuleInfo>> fetchRemoteModuleRegistry() async {
  await Future.delayed(const Duration(seconds: 1)); 
  const jsonString = '''
  [
    {
      "id": "calendar",
      "name": "Calendario",
      "author": "Equipo de Calendario",
      "version": "1.0.0",
      "enabled": true,
      "updateUrl": "https://example.com/modules/calendar/update"
    },
    {
      "id": "news",
      "name": "Noticias",
      "author": "Equipo de Noticias",
      "version": "1.0.0",
      "enabled": false
    }
  ]
  ''';
  
  // CORRECCIÓN AQUÍ: Forzamos la conversión a List<dynamic>
  final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;
  
  // Y aquí, al mapear, aseguramos que cada elemento es un Map<String, dynamic>
  return jsonData.map((item) => ModuleInfo.fromJson(item as Map<String, dynamic>)).toList();
}
