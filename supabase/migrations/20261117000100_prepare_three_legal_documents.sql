-- CONECTA ITT
-- Prepare a third versioned legal document type.
-- Stage original texts as drafts; no registration cutover.

begin;

alter table public.legal_documents
  drop constraint if exists legal_documents_type_valid;

alter table public.legal_documents
  add constraint legal_documents_type_valid
  check (document_type in (
    'terms',
    'privacy',
    'integral_notice'
  ));

-- Original text from assets/legal/terms.txt
-- SHA256: 32e5983f7b74cd4a84fdccfba4455a488dd81d9eb1e4b066f4355778eb8de5fc
insert into public.legal_documents
  (document_type, version, title, content, status)
values (
  'terms',
  'draft-2026-11-16-source',
  'Términos y Condiciones Generales de Uso',
  $conecta_terms$CONECTA-ITT



    TÉRMINOS Y CONDICIONES
      GENERALES DE USO



    Plataforma Digital de Comunicación y
           Servicios Estudiantiles



  Institución destinataria: Tecnológico Nacional de
              México, campus Tlalpan

​
Versión: 3.0​
Fecha: 3 de noviembre de 2026





                                                                            1

CAPÍTULO I. DISPOSICIONES
GENERALES

ARTÍCULO 1. Objeto y finalidad

Naturaleza: disposición interna de CONECTA-ITT.

Los presentes Términos y Condiciones tienen por objeto regular el acceso, registro,

utilización y administración de la aplicación móvil denominada CONECTA-ITT, así como

establecer  los  derechos,  obligaciones,  restricciones  y  responsabilidades de  las

personas usuarias.

La plataforma tiene como finalidad modernizar los mecanismos de comunicación del

Tecnológico Nacional de México, campus Tlalpan, mediante  la centralización de

noticias, comunicados, información académica, servicios digitales y mecanismos de

identificación institucional.

Su  utilización  deberá  realizarse respetando  los derechos fundamentales de  los

integrantes de  la comunidad educativa,  las disposiciones legales aplicables y  la

normativa institucional correspondiente.

ARTÍCULO 2. Marco jurídico aplicable

Fundamento jurídico: Constitución Política de los Estados Unidos Mexicanos; Ley

General de Protección de Datos Personales en Posesión de Sujetos Obligados; Ley

Federal de Protección de Datos Personales en Posesión de los Particulares, cuando

corresponda; y Ley Federal del Derecho de Autor.

CONECTA-ITT estará operando respetando las disposiciones legales aplicables a la

protección de datos personales, la seguridad de la información y los derechos de

propiedad intelectual.

La aplicación de cada ordenamiento dependerá de  la naturaleza  jurídica de los

responsables y de las actividades efectivamente realizadas.



                                                                            2

Los artículos de este documento constituyen disposiciones internas de uso y no deben

confundirse con los artículos de las leyes mencionadas.

ARTÍCULO 3. Ámbito de aplicación

Naturaleza: disposición interna de la organización.

Estos Términos y Condiciones serán aplicables a estudiantes, docentes, personal

administrativo, directivos, supervisores y demás personas expresamente autorizadas

para utilizar CONECTA-ITT.

El acceso a las funcionalidades estará condicionado a los permisos establecidos para

cada categoría de usuario.

ARTÍCULO 4. Aceptación de los términos

Naturaleza: disposición contractual y operativa.

Antes de completar el registro, los usuarios deberán tener la oportunidad de consultar

los presentes Términos y Condiciones y el Aviso de Privacidad correspondiente.

La aceptación de los términos deberá realizarse mediante un mecanismo que permita

dejar constancia de la versión aceptada.

La aceptación no implica  la renuncia a derechos reconocidos por  la  legislación

mexicana.





                                                                            3

CAPÍTULO II. REGISTRO Y CONTROL DE
IDENTIDAD

ARTÍCULO 5. Registro de usuarios

Fundamento jurídico relacionado: Artículo 16, párrafo segundo, de la Constitución

Política de los Estados Unidos Mexicanos, relativo a la protección de datos personales,

y legislación aplicable en dicha materia.

Con la finalidad de proteger la identidad de los integrantes de la comunidad educativa,

CONECTA-ITT establece un procedimiento de registro sujeto a validación.

Para solicitar una cuenta será necesario:

I. Proporcionar información de identificación verídica.

II. Utilizar una dirección de correo institucional válida.

III. Completar los mecanismos de autenticación habilitados.

IV. Someter la solicitud a revisión administrativa.

V. Mantener actualizados los datos necesarios para el funcionamiento de la cuenta.

La información solicitada deberá limitarse a la necesaria para cumplir las finalidades

informadas en el Aviso de Privacidad.

ARTÍCULO 6. Verificación de identidad

Fundamento jurídico relacionado: Derecho a  la protección de datos personales

reconocido en el artículo 16 constitucional y obligaciones de seguridad previstas en la

legislación de protección de datos aplicable.

Debido a que CONECTA-ITT no dispone de conexión  directa con  los  registros

académicos  oficiales, la aprobación de cuentas será realizada por administradores

autorizados.


                                                                            4

En consecuencia:

I. El correo institucional será un elemento auxiliar de identificación.

II. La terminación del correo no acreditará por sí sola el carácter de estudiante, docente

o directivo.

III. Los administradores deberán aplicar procedimientos documentados de validación.

IV. Ningún usuario podrá obtener privilegios administrativos únicamente por declarar un

cargo institucional.

V. Las  solicitudes que no puedan  verificarse permanecerán pendientes o serán

rechazadas mediante una decisión justificada.

ARTÍCULO 7. Prohibición de suplantación de identidad

Fundamento  jurídico  relacionado:  Artículo  16  constitucional  y  disposiciones

aplicables en materia de protección de datos personales. Determinadas conductas de

suplantación también podrían generar responsabilidades conforme a  la legislación

penal aplicable, según sus circunstancias.

Con el propósito de prevenir usos fraudulentos de CONECTA-ITT, se establecen las

siguientes prohibiciones:

I. Registrar cuentas con identidades falsas.

II. Utilizar fotografías, matrículas o credenciales ajenas sin autorización.

III. Hacerse pasar por personal docente, administrativo o directivo.

IV. Proporcionar documentación alterada.

V. Utilizar cuentas de terceros sin autorización.

VI. Manipular información para obtener privilegios indebidos.




                                                                            5

Los posibles incumplimientos serán investigados mediante el procedimiento interno

correspondiente, sin perjuicio de las responsabilidades legales que pudieran existir.

ARTÍCULO 8. Seguridad de las cuentas

Fundamento jurídico relacionado: Obligaciones de seguridad y confidencialidad

previstas en la legislación aplicable de protección de datos personales.

Cada usuario deberá proteger sus credenciales de autenticación.

Queda prohibido:

I. Compartir contraseñas.

II. Intentar obtener credenciales ajenas.

III. Acceder deliberadamente a cuentas de terceros sin autorización.

IV. Alterar mecanismos de autenticación.

V. Utilizar herramientas destinadas a evadir los controles de acceso.

Los usuarios deberán comunicar oportunamente cualquier sospecha de acceso no

autorizado.





                                                                            6

CAPÍTULO III. DERECHOS Y
OBLIGACIONES

ARTÍCULO 9. Derechos de los usuarios

Fundamento jurídico: Artículo 16, párrafo segundo, de la Constitución Política de los

Estados Unidos Mexicanos y legislación aplicable en materia de protección de datos

personales.

CONECTA-ITT reconoce que sus usuarios conservan los derechos que les otorga el

ordenamiento jurídico mexicano.

En consecuencia, tendrán derecho a:

I. Conocer el tratamiento de sus datos personales.

II. Ejercer los derechos de acceso, rectificación, cancelación y oposición conforme al

régimen aplicable.

III. Consultar las funcionalidades autorizadas para su perfil.

IV. Solicitar la corrección de información inexacta.

V. Reportar fallas e incidentes de seguridad.

VI. Solicitar la revisión de restricciones impuestas a su cuenta.

VII. Recibir información sobre cambios relevantes en las condiciones de uso.

ARTÍCULO 10. Obligaciones de los usuarios

Naturaleza: reglas internas de utilización responsable, relacionadas con la protección

de derechos de terceros.

Para preservar un entorno digital seguro, los usuarios deberán:

I. Utilizar la aplicación para sus finalidades autorizadas.


                                                                            7

II. Respetar la privacidad y dignidad de los integrantes de la comunidad.

III. Proporcionar información verídica.

IV. Proteger sus credenciales.

V. Abstenerse de alterar información institucional.

VI. Respetar los derechos de autor.

VII. Comunicar posibles vulneraciones de seguridad.

VIII. Cumplir las instrucciones legítimas del personal administrador dentro de sus

atribuciones.

ARTÍCULO 11. Prohibición de conductas perjudiciales

Fundamento  jurídico  relacionado: Derechos a  la  igualdad, no  discriminación,

privacidad y protección de datos reconocidos por la Constitución y las disposiciones

legales aplicables.

Para proteger la convivencia digital, queda prohibido utilizar CONECTA-ITT para:

I. Amenazar o intimidar a otros usuarios.

II. Realizar actos de acoso u hostigamiento.

III. Difundir contenido discriminatorio.

IV. Divulgar información privada sin autorización o fundamento legal.

V. Suplantar identidades.

VI. Manipular información institucional con fines perjudiciales.

VII. Utilizar las funcionalidades de la aplicación para facilitar actividades ilícitas.





                                                                            8

CAPÍTULO IV. NOTICIAS Y
COMUNICADOS

ARTÍCULO 12. Publicación de información institucional

Naturaleza: disposición interna de administración y control editorial.

Con  la finalidad de mantener  la autenticidad y organización de la información, la

publicación de noticias, comunicados y convocatorias estará reservada al personal

expresamente autorizado.

Los estudiantes podrán consultar las publicaciones y noticias para conocer los nuevos

comunicados que pública la administración.

ARTÍCULO 13. Veracidad y actualización de publicaciones

Fundamento jurídico relacionado: Derecho de acceso a la información reconocido en

el artículo 6 de la Constitución Política de los Estados Unidos Mexicanos, sin que ello

implique  que  toda  publicación  de  la  aplicación  constituya  una  obligación  de

transparencia.

Los administradores y responsables editoriales deberán procurar que las publicaciones:

I. Provengan de fuentes institucionales verificables.

II. Contengan información correcta y actualizada.

III. Identifiquen las fechas de vigencia de convocatorias y eventos.

IV. Eviten información engañosa.

V. No divulguen datos personales de manera indebida.

VI. Respeten los derechos de autor sobre fotografías y documentos.

La información incorrecta deberá ser revisada y, cuando proceda, corregida o retirada.



                                                                            9

ARTÍCULO 14. Contenido prohibido

Fundamento jurídico relacionado: Artículos 6 y 16 constitucionales; Ley Federal del

Derecho de Autor y disposiciones aplicables de protección de datos personales.

Queda prohibida la publicación de:

I. Documentos institucionales falsificados.

II. Datos personales divulgados ilícitamente.

III. Fotografías o materiales protegidos utilizados sin la autorización necesaria.

IV. Contenido discriminatorio o amenazante.

V. Comunicados destinados a suplantar autoridades.

VI.  Información manipulada deliberadamente para perjudicar a integrantes de  la

comunidad.

Las restricciones deberán aplicarse de forma proporcional y respetando los derechos

legalmente protegidos.





                                                                           10

CAPÍTULO V. SERVICIOS ACADÉMICOS Y
DIGITALES

ARTÍCULO 15. Consulta de horarios académicos

Fundamento jurídico relacionado: Artículo 16 constitucional y legislación aplicable en

materia de protección de datos personales.

Considerando  que  los  horarios  pueden  asociarse  a  estudiantes  identificados,

CONECTA-ITT deberá restringir su consulta conforme a los permisos autorizados.

Por lo anterior:

I. Cada estudiante podrá consultar su horario individual.

II. Los administradores únicamente podrán acceder a información académica cuando

sus funciones lo requieran.

III. Queda  prohibido  consultar  o  divulgar  horarios  personales de  terceros  sin

autorización o fundamento legítimo.

IV.  Los  errores  deberán  comunicarse  mediante   los  canales  institucionales

correspondientes.

V. La información presentada no modificará por  sí misma los registros escolares

oficiales.

ARTÍCULO 16. Mapa escolar

Naturaleza: disposición interna de carácter informativo y preventivo.

El mapa digital tendrá como finalidad orientar a los usuarios sobre la ubicación de

edificios, aulas, oficinas y servicios.



                                                                                11

La información estará sujeta a actualizaciones.

El mapa no sustituirá la señalización oficial, los protocolos de protección civil ni las

instrucciones del personal autorizado.

ARTÍCULO 17. Servicios digitales y trámites

Naturaleza: disposición interna de consulta institucional.

CONECTA-ITT permitirá consultar información sobre trámites, cuotas autorizadas y

servicios escolares.

Se establecen las siguientes condiciones:

I. La información deberá provenir de fuentes institucionales autorizadas.

II. Las cuotas publicadas deberán corresponder a los importes vigentes comunicados

oficialmente.

III. La aplicación no constituirá un medio de pago mientras dicha funcionalidad no esté

formalmente habilitada.

IV. Los usuarios deberán verificar los requisitos y plazos oficiales de cada trámite.

V. Los administradores deberán corregir la información que haya perdido vigencia.





                                                                           12

CAPÍTULO VI. CREDENCIAL DIGITAL

ARTÍCULO 18. Protección de la identidad estudiantil

Fundamento jurídico: Artículo 16 constitucional y legislación aplicable de protección

de datos personales.

La credencial  digital tendrá como finalidad  identificar a los usuarios y permitir  la

verificación de su condición institucional.

Su funcionamiento deberá respetar  los  principios de finalidad, proporcionalidad y

seguridad de los datos personales.

La credencial únicamente tendrá los efectos institucionales expresamente autorizados.

ARTÍCULO 19. Uso de la credencial digital

Naturaleza: disposición interna de seguridad e identificación.

La credencial digital será personal e intransferible.

Queda prohibido:

I. Prestar la credencial a terceros.

II. Utilizar credenciales ajenas.

III. Alterar fotografías o datos de identificación.

IV. Falsificar información de vigencia.

V. Utilizar la credencial para obtener accesos no autorizados.

ARTÍCULO 20. Seguridad del código QR

Fundamento jurídico relacionado: Obligaciones de seguridad y confidencialidad de

datos personales previstas en la legislación aplicable.




                                                                           13

Para  proteger  los  datos  contenidos  o  asociados a  las  credenciales  digitales,

CONECTA-ITT  deberá  implementar mecanismos  de  verificación  que  limiten  la

exposición de información personal.

Se prohíbe:

I. Manipular los mecanismos de validación.

II. Utilizar identificadores ajenos para suplantar identidades.

III. Extraer información no autorizada mediante el proceso de escaneo.

IV. Modificar las respuestas de verificación.

V. Utilizar el sistema de validación para fines ajenos a la identificación autorizada.

El diseño técnico deberá contemplar medidas contra la reutilización fraudulenta de

códigos.

ARTÍCULO 21. Fallas de identificación

Naturaleza: disposición interna de continuidad operativa.

Cuando  la credencial  digital no pueda verificarse por fallas técnicas, la institución

deberá contar con un procedimiento alternativo de identificación.

La indisponibilidad temporal de la aplicación no deberá considerarse automáticamente

prueba de que una persona carece de autorización para ingresar al campus.





                                                                           14

CAPÍTULO VII. PROTECCIÓN DE DATOS Y
SEGURIDAD INFORMÁTICA

ARTÍCULO 22. Protección de datos personales

Fundamento jurídico: Artículo 16, párrafo segundo, de la Constitución Política de los

Estados Unidos Mexicanos y Ley General de Protección de Datos Personales en

Posesión de Sujetos Obligados, cuando resulte aplicable.

El tratamiento de datos personales deberá sujetarse a las finalidades informadas en el

Aviso de Privacidad y a las obligaciones legales correspondientes.

En consecuencia:

I. Los estudiantes no podrán consultar información privada de otros usuarios.

II. Los administradores deberán limitar sus consultas a las funciones autorizadas.

III. Los datos no podrán  utilizarse para  finalidades incompatibles sin cumplir los

requisitos legales.

IV. Deberán establecerse mecanismos para atender los derechos de las personas

titulares.

V. La información deberá conservarse únicamente durante los periodos legalmente

procedentes.

ARTÍCULO 23. Seguridad informática

Fundamento jurídico relacionado: Obligaciones de seguridad de datos personales

previstas en la legislación aplicable. Las conductas que constituyan accesos ilícitos

también podrán estar sujetas a la legislación penal correspondiente.

Con  la  finalidad de  preservar  la  confidencialidad,  integridad y  disponibilidad de

CONECTA-ITT, se prohíbe:



                                                                           15

I. Acceder sin autorización a cuentas o sistemas.

II. Manipular permisos administrativos.

III. Extraer información sin autorización.

IV. Introducir código malicioso.

V. Interferir deliberadamente con los servicios.

VI. Alterar registros o datos de terceros.

VII. Realizar pruebas invasivas sin autorización expresa.

Las pruebas de seguridad legítimas deberán efectuarse conforme a procedimientos

previamente autorizados.

ARTÍCULO 24. Confidencialidad administrativa

Fundamento jurídico relacionado: Deberes de seguridad y confidencialidad previstos

en la legislación de protección de datos personales aplicable.

Los administradores, docentes y demás personas con acceso autorizado a información

personal  deberán   utilizarla  exclusivamente  para  las  finalidades  institucionales

permitidas.

Se prohíbe:

I. Consultar información por motivos personales ajenos a sus funciones.

II. Compartir credenciales administrativas.

III. Divulgar datos personales sin autorización o fundamento legal.

IV. Descargar bases de datos para usos no autorizados.

V. Conservar copias de información fuera de los procedimientos permitidos.




                                                                           16

Las  obligaciones  de  confidencialidad  continuarán  en  los  términos  legales  y

contractuales aplicables.

ARTÍCULO 25. Incidentes de seguridad

Fundamento jurídico relacionado: Disposiciones sobre medidas de seguridad y

vulneraciones de datos personales de la legislación aplicable.

Los incidentes que comprometan la información o el funcionamiento de CONECTA-ITT

deberán  ser  atendidos  mediante  procedimientos  de  identificación,  evaluación,

contención y documentación.

Las notificaciones a los titulares y autoridades se realizarán cuando resulten legalmente

exigibles.





                                                                           17

CAPÍTULO VIII. ADMINISTRACIÓN Y
MEDIDAS DISCIPLINARIAS

ARTÍCULO 26. Facultades de los administradores

Naturaleza: disposición interna de organización.

Los administradores podrán ejercer exclusivamente las funciones asignadas a su rol.

Entre ellas podrán encontrarse:

I. Revisar solicitudes de registro.

II. Aprobar o rechazar cuentas.

III. Administrar permisos.

IV. Publicar noticias y comunicados.

V. Corregir información institucional.

VI. Atender reportes.

VII. Aplicar medidas preventivas autorizadas.

Las  facultades  administrativas  no  permitirán  actuar  fuera  de  las  atribuciones

formalmente asignadas.

ARTÍCULO 27. Incumplimientos y medidas aplicables

Naturaleza: disposición interna de seguridad y control.

Cuando se detecten incumplimientos de los presentes Términos y Condiciones, podrán

adoptarse medidas proporcionales a la gravedad de los hechos.

Estas podrán comprender:




                                                                           18

I. Advertencias.

II. Solicitudes de corrección.

III. Restricción temporal de funcionalidades.

IV. Suspensión preventiva de cuentas ante riesgos de seguridad.

V. Revocación de permisos administrativos.

VI. Canalización del incidente a las autoridades institucionales competentes.

Las medidas deberán documentarse y permitir la revisión de las decisiones, de acuerdo

con los procedimientos aplicables.

ARTÍCULO 28. Revisión de medidas

Naturaleza: disposición interna de garantías procedimentales.

Los usuarios podrán solicitar la revisión de una restricción o suspensión a través del

canal designado.

La revisión deberá considerar la naturaleza del incumplimiento, la evidencia disponible,

los riesgos de seguridad y la proporcionalidad de la medida.





                                                                           19

CAPÍTULO IX. PROPIEDAD INTELECTUAL

ARTÍCULO 29. Protección jurídica del software

Fundamento jurídico: Artículos 101, 102 y 106 de la Ley Federal del Derecho de

Autor.

La Ley Federal del Derecho de Autor reconoce la protección de los programas de

computación y regula determinadas facultades de explotación patrimonial de sus

titulares.

En atención a dichas disposiciones, CONECTA-ITT establece:

I. El acceso a la aplicación no implica la transmisión de derechos patrimoniales sobre el

software.

II. La reproducción,  distribución, modificación y comercialización de componentes

protegidos   estarán   sujetas  a   las   autorizaciones   legales  o   contractuales

correspondientes.

III. Los usuarios deberán respetar los derechos de autor sobre los elementos originales

de la plataforma.

IV. Se respetarán  las excepciones y limitaciones expresamente previstas por  la

legislación aplicable.

ARTÍCULO 30. Titularidad de los derechos

Fundamento jurídico relacionado: Ley Federal del Derecho de Autor, particularmente

sus  disposiciones sobre programas de computación,  titularidad y transmisión de

derechos patrimoniales.

Los tres desarrolladores de CONECTA-ITT han manifestado su intención de conservar

una  participación  igualitaria sobre  los derechos patrimoniales que legalmente les

correspondan.



                                                                           20

La distribución pretendida será de una tercera parte para cada desarrollador.

Dicha  distribución  deberá  formalizarse mediante un convenio de  cotitularidad y

verificarse  frente a  los acuerdos de residencia profesional y demás documentos

suscritos.

Los presentes Términos y Condiciones no constituyen por sí mismos una cesión o

reconocimiento definitivo de titularidad.

ARTÍCULO 31. Licencia institucional

Fundamento jurídico relacionado: Disposiciones de la Ley Federal del Derecho de

Autor relativas a la explotación y autorización de uso de programas de computación.

La  utilización institucional de CONECTA-ITT deberá sujetarse a un convenio que

determine el alcance de la licencia otorgada.

Dicho instrumento deberá establecer las condiciones de uso, modificación, distribución,

mantenimiento, duración y terminación.

La  licencia  institucional no  implicará  automáticamente una cesión de derechos

patrimoniales.





                                                                           21

CAPÍTULO X. RESPONSABILIDADES Y
DISPONIBILIDAD

ARTÍCULO 32. Responsabilidad de los desarrolladores

Naturaleza:  disposición de  delimitación  contractual  sujeta a  la  legislación

aplicable.

Los desarrolladores responderán por las obligaciones que legal y contractualmente les

correspondan.

Las condiciones de  desarrollo, entrega, corrección de defectos, mantenimiento y

soporte deberán establecerse en los instrumentos celebrados con la institución.

La conclusión de la residencia profesional no determinará por sí sola la extinción de

obligaciones previamente asumidas.

ARTÍCULO 33. Responsabilidad institucional

Naturaleza: disposición operativa sujeta a aceptación institucional.

La institución ejercerá las funciones de administración y supervisión que formalmente

acepte.

Las responsabilidades relacionadas con la publicación de información, aprobación de

cuentas, gestión de usuarios y operación cotidiana deberán establecerse mediante

acuerdos específicos.

ARTÍCULO 34. Disponibilidad del servicio

Naturaleza: disposición interna de continuidad operativa.

CONECTA-ITT podrá experimentar interrupciones por mantenimiento, actualizaciones,

fallas técnicas o circunstancias externas.





                                                                           22

Los responsables de la operación deberán establecer procedimientos razonables de

atención y continuidad conforme a las obligaciones asumidas.

Ninguna disposición de este documento excluirá responsabilidades que legalmente no

puedan limitarse.


CAPÍTULO XI. DISPOSICIONES FINALES

ARTÍCULO 35. Modificaciones

Naturaleza: disposición interna de actualización normativa.

Los presentes Términos y Condiciones podrán modificarse cuando existan cambios

tecnológicos, funcionales, institucionales o legales.

Las modificaciones relevantes deberán comunicarse a  los usuarios mediante los

canales establecidos.

ARTÍCULO 36. Atención de solicitudes

Las consultas,  solicitudes de revisión y reportes relacionados con CONECTA-ITT

podrán presentarse mediante los canales que determine el responsable operativo.

Responsable operativo: [PENDIENTE].

Correo de contacto: cyd_tlalpan@tecnm.mx

Canal de soporte: [PENDIENTE].

ARTÍCULO 37. Interpretación

Los presentes Términos y Condiciones deberán interpretarse conforme a la legislación

mexicana aplicable.





                                                                           23

En caso de contradicción entre una disposición interna y una norma jurídica de carácter

obligatorio, prevalecerá la disposición legal correspondiente.

ARTÍCULO 38. Entrada en vigor

El presente documento entrará en vigor una vez que sea revisado y aprobado por las

partes competentes y puesto a disposición de los usuarios.

Fecha de aprobación: 03/11/2026.

Versión autorizada: 2.03





                                                                           24$conecta_terms$,
  'draft'
)
on conflict (document_type, version) do nothing;

-- Original text from assets/legal/privacy.txt
-- SHA256: 69840c8dea1d07cc667a08e16480f20a08d46c8f2716d8dbda40f528f773281d
insert into public.legal_documents
  (document_type, version, title, content, status)
values (
  'privacy',
  'draft-2026-11-16-source',
  'Políticas de Privacidad',
  $conecta_privacy$CONECTA-ITT

   POLÍTICAS DE PRIVACIDAD

  Plataforma Digital de Comunicación y
          Servicios Estudiantiles

    Tecnológico Nacional de México —
          Campus Tlalpan





Fecha de última actualización Noviembre de 2026

CONECTA-ITT​                                                               1
   POLÍTICAS DE PRIVACIDAD​                                                1
1. Identidad y Domicilio del Responsable​                                        3
2. Datos Personales que se Recaban​                                            4
3. Finalidades del Tratamiento de los Datos​                                      5
4. Transferencia de Datos​                                                     5
5. Medidas de Seguridad​                                                      6
6. Vigencia, Uso Autorizado y Suspensión de Cuentas​                             7
7. Derechos ARCO (Acceso, Rectificación, Cancelación y Oposición)​                8
8. Cambios al Aviso de Privacidad​                                              8

En cumplimiento con la Ley Federal de Protección de Datos Personales en Posesión

de los Particulares (LFPDPPP) y las normativas de protección de datos aplicables en

México, el equipo desarrollador y la administración del Tecnológico Nacional de México

Campus Tlalpan ponen a disposición de la comunidad estudiantil el presente Aviso de

Privacidad.


1. Identidad y Domicilio del Responsable


El responsable del tratamiento y protección de sus datos personales es  el área

académica y administrativa encargada de la operación de la aplicación CONECTA-ITT,

con domicilio oficial en San Miguel Topilejo, Alcaldía Tlalpan, C.P. 14100, Ciudad de

México.

Para cualquier duda, aclaración, comentario o ejercicio de sus derechos en relación

con la protección de sus datos personales, ponemos a su disposición los siguientes

canales de comunicación oficiales:

   ●​ Correo electrónico institucional de soporte / sistemas:
     cyd_tlalpan@tecnm.mx​


   ●​ Área administrativa responsable: Departamento de Sistemas y Computación /

      Subdirección Académica del TecNM Campus Tlalpan.




   ●​ Teléfono de contacto institucional: (55) 55 13 51 51




   ●​ Medios físicos y ventanilla de atención: En las instalaciones del plantel ubicadas

     en San Miguel Topilejo, Alcaldía Tlalpan, Ciudad de México, en horarios hábiles

       escolares.

2. Datos Personales que se Recaban


Para garantizar el acceso exclusivo y seguro de la comunidad estudiantil, la Aplicación

recaba y trata los siguientes datos personales y escolares:




   ●​ Datos de Identificación y Escolarizados: Nombre completo, matrícula escolar,

      carrera/semestre y grupo.




   ●​ Datos de Contacto Institucional: Correo electrónico institucional del TecNM

           .

   ●​ Datos de autenticación: Credenciales de acceso  vinculadas  al correo y

       matrícula institucional autorizados por la escuela.




   ●​ Datos de  Perfil  Estudiantil:  Fotografía para  la credencial  digital  escolar,

       horarios de clases seleccionados y configuraciones personalizadas dentro de la

      app.




   ●​ Información de Uso y Roles: Registro de perfil de usuario (asignado como

      Alumno,  Administrador  o  Supervisor),  permisos  y  acciones  funcionales

      asociadas a su rol para la gestión de avisos, noticias y directorio.

3. Finalidades del Tratamiento de los Datos



Los datos personales recabados serán utilizados estrictamente para las siguientes

finalidades necesarias para la relación académica:




   ●​ Autenticación y Seguridad:  Validar que  el acceso a  la plataforma esté

       restringido exclusivamente a alumnos y personal autorizado mediante el correo y

       matrícula institucional.




   ●​ Gestión de Servicios Escolares: Proveer  la credencial  digital  estudiantil,

       consultar el perfil escolar, visualizar el horario de clases personalizado y acceder

        al directorio institucional actualizado.




   ●​ Comunicación Institucional:  Facilitar un canal  oficial y directo de avisos,

       noticias y notificaciones escolares para erradicar rezagos en la comunicación

       interna de la escuela.




   ●​ Control de Permisos  por  Roles:  Administrar  los accesos  y  funciones

       diferenciadas según el perfil del usuario (Alumno, Administrador o Supervisor)

      para el correcto funcionamiento de las herramientas de la comunidad.


4. Transferencia de Datos

Sus datos personales son de uso interno y estrictamente institucional para la operación

de la comunidad estudiantil del TecNM Tlalpan. No se realizan transferencias de datos

personales a terceros comerciales  ni externos, salvo aquellos requerimientos de

carácter legal o solicitudes expresas de autoridades educativas competentes.

En caso de reportarse un incidente de esta índole la cuenta será suspendida hasta

nuevo aviso y el alumno responsable será sancionado.



5. Medidas de Seguridad



La Institución implementa medidas de seguridad administrativas, técnicas y físicas

razonables para proteger sus datos personales contra daño, pérdida,  alteración,

destrucción o el uso, acceso y tratamiento no autorizado, garantizando el resguardo

seguro de la información en las bases de datos y servidores autorizados.




Todo  lo anterior mencionado será supervisado, investigado y sancionado en caso de

ser necesario, los alumnos no podrán hacer uso de la aplicación en caso de ser

suspendido, ser dado de baja o haber concluido satisfactoriamente su formación en la

institución.

6. Vigencia, Uso Autorizado y Suspensión de
Cuentas



El acceso y uso de la aplicación CONECTA-ITT está estrictamente vinculado a la

condición de activo dentro de la institución.




   ●​ El uso de  la plataforma está sujeto a las normativas de conducta escolar.

      Cualquier intento de vulneración de seguridad, suplantación de identidad o uso

      indebido de  las herramientas administrativas por parte de un usuario será

       investigado y sancionado conforme a  los reglamentos internos del TecNM

       Tlalpan.




   ●​ Las cuentas de usuario serán desactivadas o suspendidas de manera temporal

     o definitiva en caso de baja escolar, suspensión temporal, o al haber concluido

       satisfactoriamente la formación académica en la institución.

7. Derechos ARCO (Acceso, Rectificación,
Cancelación y Oposición)



Usted tiene derecho en todo momento a conocer qué datos tenemos de su persona,

para qué los utilizamos y las condiciones del uso que les damos (Acceso). Asimismo,

es su derecho solicitar la corrección de su información personal en caso de estar

desactualizada, inexacta o incompleta (Rectificación); que la eliminemos de nuestros

registros cuando considere que la misma no está siendo utilizada adecuadamente

(Cancelación),  así como oponerse  al uso de sus datos para  fines  específicos

(Oposición).

Para el ejercicio de cualquiera de los derechos ARCO, el usuario podrá presentar su

solicitud formal ante el departamento administrativo o de sistemas correspondiente del

TecNM Tlalpan.


8. Cambios al Aviso de Privacidad



El presente aviso de privacidad puede sufrir modificaciones, cambios o actualizaciones

derivadas de nuevos requerimientos legales o de mejoras en la arquitectura de la

Aplicación. Cualquier modificación sustancial será notificada a través de la propia

Aplicación o mediante los canales de comunicación oficiales de la Institución.$conecta_privacy$,
  'draft'
)
on conflict (document_type, version) do nothing;

-- Original text from assets/legal/integral_notice.txt
-- SHA256: 444300eaacab904bf9910e0ba0137dff3691718848c0f2c01dc2f68005289f03
insert into public.legal_documents
  (document_type, version, title, content, status)
values (
  'integral_notice',
  'draft-2026-11-16-source',
  'Aviso de Privacidad Integral',
  $conecta_integral_notice$CONECTA-ITT

         AVISO DE PRIVACIDAD INTEGRAL

          Plataforma Digital de Comunicación y Servicios Estudiantiles

              Tecnológico Nacional de México — Campus Tlalpan



CAPÍTULO I. DISPOSICIONES GENERALES

ARTÍCULO 1. Objeto del Aviso de Privacidad

El presente Aviso de Privacidad Integral tiene como finalidad informar a los usuarios de

la  plataforma CONECTA-ITT  sobre  la  recopilación,  utilización,  almacenamiento,

conservación, protección y, en su caso, comunicación de sus datos personales.

CONECTA-ITT es una aplicación móvil desarrollada como proyecto de residencia

profesional, cuyo propósito es modernizar y centralizar la comunicación institucional,

facilitando a  la comunidad educativa  el acceso a noticias, comunicados, horarios

académicos, mapas escolares,  servicios  digitales y mecanismos de  identificación

estudiantil.

El tratamiento de datos personales deberá realizarse conforme a los principios de

licitud, finalidad, lealtad, consentimiento cuando corresponda, calidad, proporcionalidad,

información y responsabilidad previstos en la legislación aplicable.

ARTÍCULO 2. Identidad y domicilio del responsable

El responsable del tratamiento de datos personales será la persona física, moral o

institución  pública  que  determine  las  finalidades  y  los medios  esenciales  del

tratamiento.





                                                                            1

Para la operación institucional de CONECTA-ITT deberán completarse los siguientes

datos:

   ●​ Responsable: [DENOMINACIÓN OFICIAL POR CONFIRMAR].

   ●​ Domicilio: Calle Tetenco 35 Tlalpan, México City.

   ●​ Unidad responsable o de transparencia: Tecnológico Nacional de México.

   ●​ Correo electrónico: cyd_tlalpan@tecnm.mx

   ●​ Medio de atención:Instituto Tecnologico de Tlalpan.

La titularidad de los derechos de autor del software no determina, por sí misma, la
responsabilidad sobre el tratamiento de datos personales.

CAPÍTULO II. DATOS PERSONALES Y FINALIDADES

ARTÍCULO 3. Categorías de datos personales

Para proporcionar las funcionalidades de CONECTA-ITT podrán tratarse los siguientes

datos, de acuerdo con los servicios habilitados:

I. Datos de identificación: nombre completo, fotografía, matrícula o identificador

institucional y correo electrónico.

II.  Datos  académicos:  carrera,  semestre,  grupo,  horario  escolar  y  condición

institucional del usuario.

III. Datos de acceso: identificador de cuenta, rol autorizado, estado de aprobación y

datos técnicos necesarios para la autenticación.

IV.  Datos  de  interacción:  reacciones  realizadas  a  noticias  y  comunicados

institucionales.

V. Datos de verificación: identificadores y estados asociados a la credencial digital y

su código QR.

No deberán recopilar datos que resulten innecesarios para las finalidades autorizadas.





2

ARTÍCULO 4. Finalidades primarias

El tratamiento de los datos personales tendrá las siguientes finalidades:

    1.​ Registrar y autenticar a los usuarios.

    2.​ Verificar manualmente su pertenencia a la comunidad institucional.

    3.​ Asignar y administrar permisos según el rol autorizado.

    4.​ Proporcionar acceso a noticias, comunicados y convocatorias.

    5.​ Permitir la consulta individual de horarios académicos.

    6.​ Facilitar la ubicación de instalaciones escolares.

    7.​ Mostrar información relativa a servicios y trámites.

    8.​ Generar y verificar credenciales digitales.

    9.​ Prevenir accesos no autorizados.

   10.​Atender solicitudes relacionadas con la cuenta y los servicios.

ARTÍCULO 5. Finalidades secundarias

Cualquier  tratamiento  adicional, como encuestas no  indispensables,  estadísticas

identificables o comunicaciones promocionales, deberá evaluarse por separado.

Cuando corresponda, se proporcionarán mecanismos para que el titular pueda aceptar

o rechazar  las  finalidades secundarias  sin que  ello afecte injustificadamente  los

servicios esenciales.

ARTÍCULO 6. Datos personales sensibles

CONECTA-ITT no  contempla, como  parte de  sus  funcionalidades  descritas,  la

recopilación de datos relativos a salud, creencias religiosas, orientación sexual u otras

categorías de datos personales sensibles.

Si  posteriormente se  incorporan  funcionalidades que requieran esta información,

deberá realizarse una evaluación jurídica previa, actualizar  el aviso y cumplir los

requisitos aplicables.





3

La fotografía de identificación no deberá utilizarse para reconocimiento biométrico sin

una evaluación específica del tratamiento y sus obligaciones.

CAPÍTULO III. REGISTRO Y VALIDACIÓN DE IDENTIDAD

ARTÍCULO 7. Registro institucional

El registro se realizará mediante los mecanismos de identificación establecidos por la

plataforma.

La dirección de correo institucional servirá como elemento inicial de identificación, pero

no constituirá por sí sola prueba suficiente de la situación académica o laboral del

solicitante.

ARTÍCULO 8. Aprobación administrativa

Debido a que CONECTA-ITT no cuenta con acceso directo a los registros oficiales de la

institución, las solicitudes de registro estarán sujetas a verificación y aprobación por

personal autorizado.

Los  administradores deberán  utilizar  únicamente  la  información  necesaria  para

comprobar la identidad y el rol correspondiente.

ARTÍCULO 9. Exactitud y actualización

Los usuarios deberán proporcionar información verídica y comunicar las modificaciones

necesarias para mantener sus datos actualizados.

La información incorrecta podrá ser sometida a revisión mediante procedimientos

institucionales.





4

CAPÍTULO IV. CREDENCIAL DIGITAL

ARTÍCULO 10. Finalidad

La credencial digital permitirá identificar al usuario y consultar la validez de su condición

institucional mediante mecanismos electrónicos.

Su utilización como medio oficial de acceso físico al campus estará condicionada a la

autorización expresa de la institución.

ARTÍCULO 11. Protección de los datos de la credencial

La credencial podrá contener los datos de identificación necesarios para su finalidad,

tales como nombre, fotografía, matrícula, carrera y estado institucional.

El código QR deberá  utilizar un mecanismo de  verificación que  evite exponer

información personal innecesaria.

ARTÍCULO 12. Acceso a la información de validación

El personal  verificador únicamente podrá consultar los datos indispensables para

determinar la validez de la credencial.

La plataforma no deberá permitir el acceso indiscriminado a expedientes académicos,

información privada o registros personales.





5

CAPÍTULO V. SEGURIDAD Y CONFIDENCIALIDAD

ARTÍCULO 13. Medidas de seguridad

El responsable deberá establecer medidas administrativas, físicas y técnicas para

proteger los datos personales frente a pérdida, alteración, destrucción, divulgación o

acceso no autorizado.

Entre las medidas que deberán evaluarse e implementarse se encuentran:

   ●​ Control de acceso basado en roles.

   ●​ Restricción de consultas a datos personales.

   ●​ Autenticación segura.

   ●​ Protección de las comunicaciones.

   ●​ Registro y revisión de operaciones administrativas.

   ●​ Procedimientos de respuesta a incidentes.

   ●​ Gestión de respaldos y recuperación.

   ●​ Revocación de accesos cuando corresponda.

ARTÍCULO 14. Confidencialidad

Toda persona que tenga acceso autorizado a datos personales deberá mantener su

confidencialidad y  utilizarlos exclusivamente para las funciones que le hayan sido

asignadas.

Esta obligación subsistirá en los términos legales y contractuales correspondientes,

incluso cuando concluya su participación en la operación de la plataforma.

ARTÍCULO 15. Incidentes de seguridad

Cuando se detecte una posible vulneración de seguridad, los responsables deberán

activar los procedimientos de evaluación, contención, documentación y atención del

incidente.





6

Las  notificaciones a  las personas afectadas y a las autoridades competentes se

realizarán cuando resulten exigibles conforme a la legislación aplicable.

CAPÍTULO VI. ALMACENAMIENTO Y COMUNICACIÓN DE DATOS

ARTÍCULO 16. Servicios tecnológicos

CONECTA-ITT  utilizará  servicios  tecnológicos de almacenamiento  y  gestión de

información cuya identificación contractual deberá confirmarse antes de la publicación

definitiva de este aviso.

El responsable deberá verificar las condiciones de tratamiento, alojamiento, seguridad y

acceso del proveedor tecnológico.

ARTÍCULO 17. Transferencias y remisiones

La comunicación de datos personales a otras entidades se realizará únicamente

cuando exista una finalidad legítima y se cumplan las disposiciones legales aplicables.

Se  distinguirá  entre  las  transferencias a otros responsables y  las remisiones a

proveedores que traten información por cuenta del responsable.

Las transferencias que requieran consentimiento deberán sujetarse  al mecanismo

correspondiente.

ARTÍCULO 18. Conservación de información

Los datos personales se conservarán durante el tiempo necesario para cumplir las

finalidades autorizadas y las obligaciones legales aplicables.

Los periodos concretos de conservación deberán establecerse mediante una política

institucional documentada.

Cuando  proceda,   la  información  deberá  bloquearse  o  suprimirse  mediante

procedimientos seguros.




7

CAPÍTULO VII. DERECHOS DE LOS TITULARES

ARTÍCULO 19. Derechos ARCO

Las personas titulares podrán ejercer sus derechos de:

   ●​ Acceso: conocer los datos personales tratados y las condiciones de su

       tratamiento.

   ●​ Rectificación: solicitar la corrección de datos inexactos o incompletos.

   ●​ Cancelación: solicitar la cancelación de información cuando legalmente

      proceda.

   ●​ Oposición: oponerse a determinados tratamientos conforme a las disposiciones

       aplicables.

ARTÍCULO 20. Procedimiento de ejercicio

Las solicitudes deberán presentarse ante la unidad, departamento o medio designado

por el responsable.

Canal de recepción: [PENDIENTE].

Datos de contacto: [PENDIENTE].

Procedimiento de identificación: [PENDIENTE].

Plazos y medios de respuesta: los previstos en el régimen jurídico aplicable.

No podrán exigirse requisitos adicionales que restrinjan injustificadamente el ejercicio

de estos derechos.

ARTÍCULO 21. Limitación del tratamiento y consentimiento

Cuando legalmente proceda, los titulares podrán solicitar la limitación de determinados

usos de su información o revocar el consentimiento previamente otorgado.

La procedencia y los efectos de estas solicitudes dependerán de la base jurídica que

sustente el tratamiento.


8

CAPÍTULO VIII. MODIFICACIONES Y VIGENCIA

ARTÍCULO 22. Actualizaciones

El presente Aviso de Privacidad podrá modificarse cuando existan cambios normativos,

administrativos,  tecnológicos o  funcionales que  afecten  el  tratamiento de datos

personales.

Las modificaciones deberán comunicarse mediante los medios oficiales que establezca

el responsable.

ARTÍCULO 23. Disponibilidad

El Aviso de Privacidad Integral deberá mantenerse disponible para su consulta dentro

de CONECTA-ITT, especialmente durante el registro de usuarios y desde una sección

permanente de privacidad.

ARTÍCULO 24. Entrada en vigor

El presente aviso entrará en vigor únicamente cuando se complete la información

pendiente, se determine  el responsable del tratamiento y sea aprobado por  las

personas o autoridades competentes.





9$conecta_integral_notice$,
  'draft'
)
on conflict (document_type, version) do nothing;

commit;
