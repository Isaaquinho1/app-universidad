import 'package:event_bus/event_bus.dart';
import 'package:mini_app/src/remote_config_service.dart';
import 'package:mini_app/src/remote_registry.dart';

/// Глобальный экземпляр EventBus для обмена событиями между модулями
EventBus eventBus = EventBus();

/// Пример события для модулей
class ModuleEvent {
  ModuleEvent(this.moduleId, this.message);
  final String moduleId;
  final String message;
}

/// Инициализация настроек (теперь использует ваши локальные сервисы)
Future<void> _initializeRemoteSettings() async {
  try {
    // 1. Cargamos configuración local de prueba (reemplazo del cliente externo)
    RemoteConfigService.setConfig({
      "module_calendar_enabled": true,
      "module_calendar_version": "1.0.0"
    });

    // 2. Obtenemos el registro de módulos que definiste
    final remoteModules = await fetchRemoteModuleRegistry();
    
    for (final moduleInfo in remoteModules) {
      final bool featureEnabled = RemoteConfigService.isModuleEnabled(moduleInfo.id);
      final String? requiredVersion = RemoteConfigService.getModuleVersion(moduleInfo.id);
      
      if (moduleInfo.enabled && featureEnabled && (requiredVersion == moduleInfo.version)) {
        if (moduleInfo.id == 'calendar') {
          print('Registrando mini-app: ${moduleInfo.name}');
          // Aquí puedes llamar a tu lógica de registro real
        }
      } else {
        print('Módulo ${moduleInfo.id} deshabilitado o versión incorrecta');
      }
    }
  } catch (e) {
    print('Error en la inicialización: $e');
  }
}
