# Contribuir a Conecta ITT

Gracias por tu interés en Conecta ITT, aplicación móvil para la
comunidad del Tecnológico Nacional de México Campus Tlalpan.

## Alcance

El desarrollo activo está dirigido exclusivamente a Android e iOS.

La aplicación incluye comunicados institucionales, notificaciones,
perfiles, gestión académica personal y servicios estudiantiles.

## Tecnologías

- Flutter y Dart.
- Supabase.
- Firebase.
- BLoC y Cubit.
- Paquetes internos en `packages/`.

## Repositorio

Clonar el proyecto:

    git clone https://github.com/Isaaquinho1/app-universidad.git
    cd app-universidad

Rama estable de desarrollo:

    refactor/conecta-itt-identity

Antes de desarrollar, comprobar la rama y el estado de Git:

    git branch --show-current
    git status --short

## Preparación del entorno

Instalar Flutter, Dart y las herramientas de Android o iOS.

El proyecto utiliza FVM para administrar Flutter.

    fvm install
    fvm flutter pub get

Ejecutar la configuración de desarrollo:

    fvm flutter run --flavor development -t lib/main/main_development.dart

La ejecución de servicios externos requiere configuración autorizada.

No publicar credenciales ni claves privadas.

## Validación

Antes de proponer modificaciones:

    fvm flutter analyze
    fvm flutter test

Distinguir las advertencias existentes de errores introducidos
por los cambios.

Verificar en Android e iOS cuando corresponda.

## Convenciones

- Organizar el código por funcionalidades.
- Documentar las decisiones importantes.
- Utilizar nombres descriptivos.
- Escribir los textos visibles en español de México.
- Mantener la compatibilidad de los datos persistidos.
- No introducir integraciones institucionales sin autorización.
- No incluir credenciales en el código fuente.
- Revisar el impacto antes de modificar migraciones o esquemas.

## Commits

Utilizar commits pequeños y descriptivos, preferentemente con
el estilo Conventional Commits.

Ejemplos:

- feat: nueva funcionalidad
- fix: corrección funcional
- refactor: reorganización de código
- docs: actualización documental
- chore: mantenimiento del proyecto

Verificar los cambios antes de confirmar:

    git status --short
    git diff --check

No incluir archivos temporales, respaldos personales ni
configuraciones locales ajenas a la modificación.

## Licencias y atribución

Conecta ITT parte de software previamente existente.

Se deben respetar las condiciones de licencia y los avisos
de copyright conservados en `LICENSE`.

El historial anterior permanece disponible mediante Git.

## Seguridad

No compartir datos personales de estudiantes, tokens FCM,
claves privadas, credenciales de Supabase o Firebase ni
información institucional restringida.
