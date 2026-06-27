// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get scheduleAppBarTitle => 'Horario';

  @override
  String get loadingError => 'Error de carga';

  @override
  String get imageViewer => 'Visor de imágenes';

  @override
  String get selectDate => 'Seleccionar fecha';

  @override
  String get selectDates => 'Seleccionar fechas';

  @override
  String get enableComparisonMode => 'Activar modo comparación';

  @override
  String get disableComparisonMode => 'Desactivar modo comparación';

  @override
  String get compareSchedules => 'Comparar horarios';

  @override
  String get noClassesToday => 'No hay clases hoy';

  @override
  String get selectTime => 'Seleccionar hora';

  @override
  String get clear => 'Limpiar';

  @override
  String get month => 'Mes';

  @override
  String get week => 'Semana';

  @override
  String get apply => 'Aplicar';

  @override
  String get previousDay => 'Día anterior';

  @override
  String get nextDay => 'Día siguiente';

  @override
  String get today => 'Hoy';

  @override
  String get refreshData => 'Actualizar datos';

  @override
  String get scheduleComparison => 'Comparación de horarios';

  @override
  String get scheduleAnalytics => 'Analítica de horarios';

  @override
  String get allClassesList => 'Lista de todas las clases';

  @override
  String get scheduleNotSelected => 'Horario no seleccionado';

  @override
  String get findSchedule => 'Buscar horario';

  @override
  String get scheduleForSelectedDay => 'Horario para el día seleccionado';

  @override
  String get tomorrow => 'Mañana';

  @override
  String get showEmptyClasses => 'Mostrar clases vacías';

  @override
  String get emptyClasses => 'Clases vacías';

  @override
  String get analytics => 'Analítica';

  @override
  String get weekend => 'Fin de semana';

  @override
  String get noClassesThisDay => 'No hay clases este día';

  @override
  String get canRestOrStudy =>
      'Puedes descansar o realizar trabajo independiente';

  @override
  String get goToAnotherDay => 'Ir a otro día';

  @override
  String classesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clases',
      one: '1 clase',
      zero: 'sin clases',
    );
    return '$_temp0';
  }

  @override
  String get noClass => 'Sin clase';

  @override
  String get displaySettings => 'Ajustes de visualización';

  @override
  String get showCommentIndicators => 'Mostrar indicadores de comentarios';

  @override
  String get compactCardMode => 'Modo de tarjeta compacta';

  @override
  String get lecture => 'Clase magistral';

  @override
  String get laboratory => 'Laboratorio';

  @override
  String get practice => 'Práctica';

  @override
  String get exam => 'Examen';

  @override
  String get consultation => 'Consulta';

  @override
  String get credit => 'Crédito';

  @override
  String get unknown => 'Desconocido';

  @override
  String get lessonType => 'Tipo de clase';

  @override
  String get individual => 'Individual';

  @override
  String get physicalEducation => 'Educación física';

  @override
  String get courseWork => 'Trabajo de curso';

  @override
  String get courseProject => 'Proyecto de curso';

  @override
  String get mapsOnlyOnMobile =>
      'Los mapas solo están disponibles en dispositivos móviles';

  @override
  String get scheduleAnalyticsTitle => 'Analítica de horarios';

  @override
  String get scheduleAnalyticsDescription =>
      'Estadísticas y análisis de tu horario académico';

  @override
  String get loadByDays => 'Carga por días';

  @override
  String get lessonTypes => 'Tipos de clases';

  @override
  String get teachers => 'Profesores';

  @override
  String get classrooms => 'Aulas';

  @override
  String get noDataForAnalytics => 'No hay datos para la analítica';

  @override
  String get selectAnotherSchedule =>
      'Selecciona otro horario o verifica si hay clases';

  @override
  String get exportData => 'Exportar datos';

  @override
  String get fullReportWithCharts => 'Informe completo con todos los gráficos';

  @override
  String get dataInTableFormat => 'Datos en formato de tabla';

  @override
  String get shareImage => 'Compartir imagen';

  @override
  String get currentOrAllCharts => 'Gráfico actual o todos';

  @override
  String get export => 'Exportar';

  @override
  String get monday => 'Lunes';

  @override
  String get tuesday => 'Martes';

  @override
  String get wednesday => 'Miércoles';

  @override
  String get thursday => 'Jueves';

  @override
  String get friday => 'Viernes';

  @override
  String get scheduleChanges => 'Cambios en el horario';

  @override
  String get calendar => 'Calendario';

  @override
  String get scheduleLoadingError => 'Error al cargar el horario';

  @override
  String get addSchedulesForComparison => 'Añadir horarios para comparar';

  @override
  String get buildRoute => 'Trazar ruta';

  @override
  String get mySchedules => 'Mis horarios';

  @override
  String get createSchedule => 'Crear horario';

  @override
  String get addClass => 'Añadir clase';

  @override
  String get classesList => 'Lista de clases';

  @override
  String get classLabel => 'Clase';

  @override
  String get open => 'Abrir';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Eliminar';

  @override
  String get editSchedule => 'Editar horario';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get deleteSchedule => 'Eliminar horario';

  @override
  String deleteScheduleConfirmation(String scheduleName) {
    return '¿Estás seguro de que quieres eliminar el horario \"$scheduleName\"?';
  }

  @override
  String get createNewClass => 'Crear nueva clase';

  @override
  String get noAddedClasses => 'No hay clases añadidas';

  @override
  String get deleteClass => 'Eliminar clase';

  @override
  String deleteClassConfirmation(String subject) {
    return '¿Estás seguro de que quieres eliminar la clase \"$subject\" del horario?';
  }

  @override
  String get start => 'Inicio';

  @override
  String get end => 'Fin';

  @override
  String get endTimeMustBeAfterStart =>
      'La hora de fin debe ser posterior a la hora de inicio';

  @override
  String get classNumber => 'Número de clase';

  @override
  String get none => 'Ninguno';

  @override
  String get groups => 'Grupos';

  @override
  String get noTeachersSelected => 'No hay profesores seleccionados';

  @override
  String get addTeacher => 'Añadir profesor';

  @override
  String get add => 'Añadir';

  @override
  String get selectAtLeastOneDate => 'Selecciona al menos una fecha';

  @override
  String get addAtLeastOneClassroom =>
      'Añade al menos un aula o marca la clase como online';

  @override
  String get noSelectedDates => 'No hay fechas seleccionadas';

  @override
  String get selectDatesButton => 'Seleccionar fechas';

  @override
  String get noSelectedClassrooms => 'No hay aulas seleccionadas';

  @override
  String get addClassroom => 'Añadir aula';

  @override
  String get noGroupsSelected => 'No hay grupos seleccionados';

  @override
  String get addGroup => 'Añadir grupo';

  @override
  String get exampleClassNames => 'Ejemplos de nombres de clase:';

  @override
  String get textCopied => '¡Texto copiado!';

  @override
  String failedToOpenImage(String error) {
    return 'No se pudo abrir la imagen: $error';
  }

  @override
  String get loginFailed => 'Error de inicio de sesión';

  @override
  String get next => 'Siguiente';

  @override
  String get errorLoadingSponsors => 'Error al cargar los patrocinadores';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get loginToContinue => 'Inicia sesión para continuar';

  @override
  String get deleteScheduleTitle => 'Eliminar horario';

  @override
  String get deleteScheduleMessage =>
      '¿Estás seguro de que quieres eliminar este horario?';

  @override
  String get makeActive => 'Activar';

  @override
  String get comment => 'Comentario';

  @override
  String get schedules => 'Horarios';

  @override
  String get loadingSchedules => 'Cargando horarios...';

  @override
  String get addedClass => 'Clase añadida:';

  @override
  String get createNewSchedule => 'Crear nuevo horario';

  @override
  String get selectSchedule => 'Seleccionar horario:';

  @override
  String classAddedToSchedule(String scheduleName) {
    return 'Clase añadida al horario \"$scheduleName\"';
  }

  @override
  String get legends => 'Leyendas';

  @override
  String get maxThreeSchedules => 'Máximo 3 horarios para comparar';

  @override
  String get university => 'Universidad';

  @override
  String get search => 'Buscar';

  @override
  String get all => 'Todos';

  @override
  String get error => 'Error';

  @override
  String get searchFailed => 'Error al realizar la búsqueda';

  @override
  String get enterCommentText => 'Introduce el texto del comentario...';

  @override
  String get remove => 'Eliminar';

  @override
  String get noAvailableSchedules => 'No hay horarios disponibles';

  @override
  String get scheduleDeleted => 'Horario eliminado';

  @override
  String get deleteScheduleConfirmationDialog =>
      '¿Estás seguro de que quieres eliminar este horario?';

  @override
  String get active => 'Activo';

  @override
  String get comments => 'Comentarios';

  @override
  String get activate => 'Activar';

  @override
  String get group => 'Grupo';

  @override
  String get teacher => 'Profesor';

  @override
  String get classroom => 'Aula';

  @override
  String get schedule => 'Horario';

  @override
  String get commentDeleted => 'Comentario eliminado';

  @override
  String get commentSaved => 'Comentario guardado';

  @override
  String get scheduleComment => 'Comentario del horario';

  @override
  String get addOrEditNote => 'Añadir o editar una nota en el horario';

  @override
  String get editComment => 'Editar comentario';

  @override
  String get addComment => 'Añadir comentario';

  @override
  String get addSchedule => 'Añadir horario';

  @override
  String get activeSchedule => 'Horario activo';

  @override
  String get goToView => 'Ir a la vista';

  @override
  String get noAddedGroups => 'No hay grupos añadidos';

  @override
  String get addGroupToSeeSchedule => 'Añade un grupo para ver su horario';

  @override
  String get noAddedTeachers => 'No hay profesores añadidos';

  @override
  String get addTeacherToSeeSchedule => 'Añade un profesor para ver su horario';

  @override
  String get noAddedClassrooms => 'No hay aulas añadidas';

  @override
  String get addClassroomToSeeSchedule => 'Añade un aula para ver su horario';

  @override
  String get failedToLoadSchedules => 'Error al cargar los horarios';

  @override
  String get checkInternetConnection => 'Comprueba tu conexión a internet';

  @override
  String get enterJsonString => 'Por favor, introduce la cadena JSON';

  @override
  String get enterJsonStringPlaceholder => 'Introduce la cadena JSON...';

  @override
  String get tabs => 'Pestañas';

  @override
  String get scheduleChangesTitle => 'Cambios en el horario';

  @override
  String get loadByDaysChart => 'Carga por días';

  @override
  String get lessonTypesChart => 'Tipos de clases';

  @override
  String get teachersChart => 'Profesores';

  @override
  String get classroomsChart => 'Aulas';

  @override
  String get fullReportWithAllCharts =>
      'Informe completo con todos los gráficos';

  @override
  String get dataInTableFormatExport => 'Datos en formato de tabla';

  @override
  String get shareImageExport => 'Compartir imagen';

  @override
  String get currentOrAllChartsExport => 'Gráfico actual o todos';

  @override
  String get totalClasses => 'Total de clases';

  @override
  String get forEntirePeriod => 'Para todo el período';

  @override
  String get averagePerDay => 'Promedio por día';

  @override
  String get academicLoad => 'Carga académica';

  @override
  String get maximumPerDay => 'Máximo por día';

  @override
  String get busiestDay => 'Día con más carga';

  @override
  String get showEmptyClassesSettings => 'Mostrar clases vacías';

  @override
  String get showCommentIndicatorsSettings =>
      'Mostrar indicadores de comentarios';

  @override
  String get compactCardModeSettings => 'Modo de tarjeta compacta';

  @override
  String get holiday => 'Festivo';

  @override
  String get selectExisting => 'Seleccionar existente';

  @override
  String get createNew => 'Crear nuevo';

  @override
  String get scheduleName => 'Nombre del horario';

  @override
  String get scheduleNamePlaceholder => 'Por ejemplo: Mi horario principal';

  @override
  String get descriptionOptional => 'Descripción (opcional)';

  @override
  String get addScheduleDescription => 'Añadir descripción del horario';

  @override
  String get openSchedule => 'Abrir';

  @override
  String get selectWeek => 'Seleccionar semana';

  @override
  String get quickWayToWeek => 'Manera rápida de ir a una semana específica';

  @override
  String get selectUpToFourSchedules =>
      'Selecciona hasta 4 horarios para compararlos por días';

  @override
  String get addToSchedule => 'Añadir al horario';

  @override
  String get enterLessonComment => 'Introduce un comentario para la clase...';

  @override
  String get noOwnSchedules => 'Aún no tienes tus propios horarios';

  @override
  String get createCustomSchedule =>
      'Crea un horario personalizado añadiendo clases de diferentes horarios disponibles';

  @override
  String get scheduleCreation => 'Creación de horario';

  @override
  String get enterNameAndDescription =>
      'Introduce el nombre y la descripción para el nuevo horario';

  @override
  String get scheduleNameLabel => 'Nombre del horario';

  @override
  String get scheduleNameExample => 'Por ejemplo: Mi horario';

  @override
  String get descriptionOptionalLabel => 'Descripción (opcional)';

  @override
  String get addScheduleDescriptionPlaceholder =>
      'Añadir descripción del horario';

  @override
  String get editScheduleTitle => 'Editar horario';

  @override
  String get classesListTitle => 'Lista de clases';

  @override
  String addNewClassToSchedule(String scheduleName) {
    return 'Puedes añadir una nueva clase al horario $scheduleName';
  }

  @override
  String get offline => 'Sin conexión';

  @override
  String get online => 'En línea';

  @override
  String get subjectName => 'Nombre de la asignatura';

  @override
  String get enterSubjectName => 'Introduce el nombre de la asignatura';

  @override
  String get teacherFullName => 'Nombre completo del profesor';

  @override
  String get teacherNameExample => 'Por ejemplo: Juan Pérez Pérez';

  @override
  String get endTimeMustBeAfterStartTime =>
      'La hora de fin debe ser posterior a la hora de inicio';

  @override
  String get selectAtLeastOneDateError => 'Selecciona al menos una fecha';

  @override
  String get addAtLeastOneClassroomError =>
      'Añade al menos un aula o marca la clase como online';

  @override
  String get selectDatesButtonText => 'Seleccionar fechas';

  @override
  String get onlineClassLink => 'Enlace de la clase online';

  @override
  String get enterConnectionUrl => 'Introduce la URL de conexión';

  @override
  String classroomNumber(String name) {
    return 'Aula $name';
  }

  @override
  String get classroomExample => 'Por ejemplo: A-123';

  @override
  String get campusNameOptional => 'Nombre del campus (opcional)';

  @override
  String get campusExample => 'Por ejemplo: B-78';

  @override
  String get addClassroomDialog => 'Añadir aula';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get groupNameExample => 'Por ejemplo: IKBO-01-21';

  @override
  String get addGroupDialog => 'Añadir grupo';

  @override
  String get retry => 'Reintentar';

  @override
  String get resetFilter => 'Restablecer filtro';

  @override
  String get supportOurService => 'Apoya nuestro servicio';

  @override
  String get leaveAd => 'Dejar anuncio';

  @override
  String get disable => 'Desactivar';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get map => 'Mapa';

  @override
  String get tryAgain => 'Intentar de nuevo';

  @override
  String get announcement => 'Anuncio';

  @override
  String get contact => 'Contacto';

  @override
  String copiedToClipboard(String title) {
    return '$title copiado al portapapeles';
  }

  @override
  String get post => 'Publicación';

  @override
  String get errorLoadingPost => 'Error al cargar la publicación';

  @override
  String get errorLoadingContributors => 'Error al cargar los colaboradores';

  @override
  String get relatedArticles => 'Artículos relacionados';

  @override
  String get failedToLoadArticle => 'Error al cargar el artículo';

  @override
  String get shareFailed => 'Error al compartir';

  @override
  String get trending => 'Tendencias';

  @override
  String get slideshow => 'Presentación';

  @override
  String get enterSearchQuery => 'Introduce una consulta de búsqueda';

  @override
  String get failedToLoadMoreContent => 'Error al cargar más contenido';

  @override
  String get searchHistory => 'Historial';

  @override
  String get enterScheduleName => 'Introduce un nombre';

  @override
  String get nameTooLong => 'El nombre es demasiado largo';

  @override
  String get createAndAddClass => 'Crear y añadir clase';

  @override
  String get addToSelectedSchedule => 'Añadir al horario seleccionado';

  @override
  String get mireaMap => 'Mapa MIREA';

  @override
  String get findNeededClassroom => 'Encuentra el aula necesaria';

  @override
  String get nfcPass => 'Pase NFC';

  @override
  String get passForUniversityEntry => 'Pase para la entrada a la universidad';

  @override
  String get cloudMireaNinja => 'Cloud Mirea Ninja';

  @override
  String get mireaNinja => 'Mirea Ninja';

  @override
  String get mostPopularUnofficialChat => 'El chat no oficial más popular';

  @override
  String get kisDepartment => 'Departamento KIS';

  @override
  String get corporateInformationSystems =>
      'Departamento de Sistemas de Información Corporativa';

  @override
  String get ippoDepartment => 'Departamento IPPO';

  @override
  String get instrumentalAndAppliedSoftware =>
      'Departamento de Software Instrumental y Aplicado';

  @override
  String get competitiveProgrammingMirea => 'Programación Competitiva MIREA';

  @override
  String get competitiveProgrammingDescription =>
      'Aquí se publican diversas noticias y actualizaciones sobre programación competitiva en MIREA';

  @override
  String get personalAccount => 'Cuenta Personal';

  @override
  String get accessToGradesAndServices =>
      'Acceso a calificaciones, solicitudes y otros servicios';

  @override
  String get openAction => 'Abrir';

  @override
  String get educationalPortal => 'Portal Educativo';

  @override
  String get accessToCoursesAndMaterials => 'Acceso a cursos y materiales';

  @override
  String get goToAction => 'Ir a';

  @override
  String get electronicJournal => 'Diario Electrónico';

  @override
  String get attendanceCheckSchedule => 'Control de asistencia, horario';

  @override
  String get library => 'Biblioteca';

  @override
  String get freeSoftware => 'Software Libre';

  @override
  String get cyberzone => 'Ciberzona';

  @override
  String get handbook => 'Manual';

  @override
  String get scholarships => 'Becas';

  @override
  String get militaryRegistration => 'Registro Militar';

  @override
  String get dormitories => 'Residencias';

  @override
  String get studentOffice => 'Oficina de Estudiantes';

  @override
  String get certificatesDocumentsQuestions =>
      'Certificados, documentos, preguntas';

  @override
  String get careerCenter => 'Centro de Carreras';

  @override
  String get vacanciesAndInternships => 'Vacantes y prácticas profesionales';

  @override
  String get initiativeService => 'Servicio de Iniciativas';

  @override
  String get ideasAndSuggestions => 'Ideas y sugerencias';

  @override
  String get virtualTour => 'Recorrido Virtual';

  @override
  String get interactiveUniversityTour =>
      'Recorrido interactivo por los edificios de la universidad';

  @override
  String get startupAccelerator => 'Aceleradora de Startups';

  @override
  String get startupSupport => 'Apoyo a startups e ideas emprendedoras';

  @override
  String get corporatePortal => 'Portal Corporativo';

  @override
  String get accessForTeachersAndStaff => 'Acceso para profesores y personal';

  @override
  String get mainServices => 'Servicios principales';

  @override
  String get studentLife => 'Vida estudiantil';

  @override
  String get useful => 'Útil';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get createAccountTitle => 'Crear una cuenta';

  @override
  String get createAccountDescription =>
      '¡Te ofrecemos crear una cuenta gratuita en nuestro almacenamiento en la nube para que puedas guardar tus archivos y documentos!';

  @override
  String get cloudStorageDescription =>
      'En cloud.mirea.ninja puedes almacenar hasta 10 GB de forma gratuita (la cuota se puede ampliar en el bot de telegram), así como compartir archivos y editar documentos en línea junto con tus compañeros.';

  @override
  String get searchPlaceholder => 'Buscar';

  @override
  String get searchInAnnouncements => 'Buscar en anuncios...';

  @override
  String get itemName => 'Nombre del objeto';

  @override
  String get itemNameExample => 'Por ejemplo: Llaves con llavero';

  @override
  String get description => 'Descripción';

  @override
  String get itemDescription =>
      'Detalles sobre el objeto, dónde y cuándo se encontró/perdió...';

  @override
  String get telegram => 'Telegram';

  @override
  String get phone => 'Teléfono';

  @override
  String get leaveFeedback => 'Dejar comentarios';

  @override
  String get yourEmail => 'Tu correo electrónico';

  @override
  String get enterEmail => 'Introduce tu correo electrónico';

  @override
  String get whatHappened => '¿Qué ha sucedido?';

  @override
  String get feedbackPlaceholder => 'Cuando pulso \"X\" ocurre \"Y\"';

  @override
  String get exportToCalendar => 'Exportar al calendario';

  @override
  String get scheduleExported => 'Horario exportado';

  @override
  String get failedToExportSchedule => 'Error al exportar el horario';

  @override
  String get exportSettings => 'Configuración de exportación';

  @override
  String get emojiInLessonTypes => 'Emoji en los tipos de lección';

  @override
  String get emojiExample => 'Ejemplo: \"📚 Clase\" en lugar de \"Clase\"';

  @override
  String get shortLessonTypeNames => 'Nombres cortos para tipos de lección';

  @override
  String get shortNamesExample => 'Ejemplo: \"Cl.\" en lugar de \"Clase\"';

  @override
  String get preview => 'Vista previa';

  @override
  String get fullTypeName => 'Nombre completo del tipo';

  @override
  String get shortTypeName => 'Nombre corto del tipo';

  @override
  String get subjectSelection => 'Selección de asignatura';

  @override
  String get standardReminders => 'Recordatorios estándar';

  @override
  String get cardSettings => 'Configuración de tarjeta';

  @override
  String get codeFromEmail => 'Código del correo electrónico';

  @override
  String get news => 'Noticias';

  @override
  String get services => 'Servicios';

  @override
  String get profile => 'Perfil';

  @override
  String get aboutApp => 'Acerca de la aplicación';

  @override
  String get settings => 'Configuración';

  @override
  String get findScheduleForClassroom =>
      'Puedes encontrar rápidamente un horario para esta aula usando la búsqueda de horarios.';

  @override
  String get newYearHolidays => 'Vacaciones de Año Nuevo';

  @override
  String get winterVacation => 'Vacaciones de invierno';

  @override
  String get defenderOfFatherlandDay => 'Día del Defensor de la Patria';

  @override
  String get internationalWomensDay => 'Día Internacional de la Mujer';

  @override
  String get springAndLaborDay => 'Día de la Primavera y del Trabajo';

  @override
  String get victoryDay => 'Día de la Victoria';

  @override
  String get russiaDay => 'Día de Rusia';

  @override
  String get nationalUnityDay => 'Día de la Unidad Nacional';

  @override
  String get newYear => 'Año Nuevo';

  @override
  String get total => 'Total';

  @override
  String get lectures => 'Clases magistrales';

  @override
  String get practicals => 'Prácticas';

  @override
  String get labs => 'Laboratorios';

  @override
  String get justNow => 'hace un momento';

  @override
  String get status => 'Estado';

  @override
  String phoneContact(String phoneNumber) {
    return 'Teléfono: $phoneNumber';
  }

  @override
  String lessonsOnDay(String day) {
    return 'Clases del $day';
  }

  @override
  String get todayLower => 'hoy';

  @override
  String get tomorrowLower => 'mañana';

  @override
  String get showEmptyLessonsTooltip => 'Mostrar clases vacías';

  @override
  String get emptyLessons => 'Clases vacías';

  @override
  String get analyticsShort => 'Analíticas';

  @override
  String get dayOff => 'Día libre';

  @override
  String get noLessonsThatDay => 'No hay clases este día';

  @override
  String get noLessonsThatDayShort => '¡No hay clases este día!';

  @override
  String get restSuggestion => 'Puedes descansar o estudiar por tu cuenta';

  @override
  String windowGap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clases',
      one: '$count clase',
    );
    return 'Ventana: $_temp0';
  }

  @override
  String get noScheduleSelected => 'No hay horario seleccionado';

  @override
  String get selectEntityToSeeSchedule =>
      'Selecciona un grupo, profesor o aula para ver el horario';

  @override
  String get errorLoadingSchedule => 'Error al cargar el horario';

  @override
  String get manageComparisons => 'Gestionar comparaciones';

  @override
  String get selectUpTo4Schedules =>
      'Selecciona hasta 4 horarios para comparar por días';

  @override
  String get noUpcomingLessons => 'No hay clases próximas';

  @override
  String get noUpcomingLessonsDescription =>
      'No hay clases programadas en un futuro cercano. Cambia al calendario para ver otros días.';

  @override
  String get switchToCalendar => 'Cambiar al calendario';

  @override
  String get lecturesShort => 'Mag.';

  @override
  String get practiceShort => 'Práct.';

  @override
  String get labsShort => 'Lab.';

  @override
  String get legend => 'Leyenda';

  @override
  String get laboratoryWork => 'Laboratorio';

  @override
  String get scheduleLoadError =>
      'Ocurrió un error al obtener el horario. Por favor, intenta de nuevo.';

  @override
  String get selectSchedulesForComparison =>
      'Seleccionar horarios para comparar (hasta 3)';

  @override
  String deleteScheduleConfirm(String name) {
    return '¿Estás seguro de que quieres eliminar \"$name\"?';
  }

  @override
  String deleteClassConfirm(String subject) {
    return '¿Estás seguro de que quieres eliminar \"$subject\" del horario?';
  }

  @override
  String get commentTooLong => 'El comentario es demasiado largo';

  @override
  String get addOneClassroomOrOnline =>
      'Añade al menos una aula o marca la clase como en línea';

  @override
  String get createClass => 'Crear clase';

  @override
  String get editClass => 'Editar clase';

  @override
  String get startTime => 'Inicio';

  @override
  String get endTime => 'Fin';

  @override
  String get lessonNumber => 'Número de lección';

  @override
  String get teacherFullNameHint => 'ej. Ivanov Iván Ivánovich';

  @override
  String get enterTeacherFullName =>
      'Introduce el nombre completo del profesor';

  @override
  String get onlineLessonUrl => 'URL de la clase en línea';

  @override
  String get enterUrl => 'Introduce una URL';

  @override
  String get classroomNumberHint => 'ej. A-123';

  @override
  String get enterClassroomNumber => 'Introduce el número de aula';

  @override
  String get enterGroupName => 'Introduce el nombre del grupo';

  @override
  String get basic => 'Básico';

  @override
  String get dates => 'Fechas';

  @override
  String get place => 'Lugar';

  @override
  String get create => 'Crear';

  @override
  String get addDate => 'Añadir fecha';

  @override
  String get lessonDeliveryType => 'Tipo de impartición de la clase';

  @override
  String get noClassroomsSelected => 'No hay aulas seleccionadas';

  @override
  String get back => 'Atrás';
}
