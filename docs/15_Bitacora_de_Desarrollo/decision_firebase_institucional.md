# Decisión técnica: Firebase institucional para Conecta ITT

## Contexto

El repositorio base contiene configuración Firebase heredada del proyecto original. Para la adaptación institucional de Conecta ITT se requiere crear y configurar un proyecto Firebase propio, independiente del proyecto original.

## Decisión

Se utilizará un nuevo proyecto Firebase exclusivo para Conecta ITT. Este proyecto será utilizado para autenticación, notificaciones, configuración remota y otros servicios que se habiliten durante el desarrollo institucional.

## Archivos involucrados

Los archivos que serán reemplazados posteriormente son:

- lib/firebase_options.dart
- android/app/google-services.json
- android/app/src/debug/google-services.json
- ios/Runner/GoogleService-Info.plist

## Criterios de seguridad

No se reutilizarán credenciales, identificadores ni configuraciones Firebase del repositorio original.

No se modificará todavía el package name de Android ni el Bundle Identifier de iOS hasta completar la validación inicial del nuevo proyecto Firebase.

## Proyecto Firebase propuesto

Nombre sugerido:

Conecta ITT

Identificadores sugeridos:

- Android: mx.tecnm.tlalpan.conectaitt
- iOS: mx.tecnm.tlalpan.conectaitt
- Web/Admin: conecta-itt-admin

## Pendientes

- Crear proyecto Firebase institucional.
- Registrar aplicación Android.
- Registrar aplicación iOS.
- Registrar aplicación web.
- Ejecutar flutterfire configure.
- Reemplazar archivos de configuración.
- Validar ejecución en entorno development.
