import 'package:flutter/material.dart';
import 'package:app_ui/app_ui.dart';
import 'package:conecta_itt/services/models/service_model.dart';

/// Services configuration for TecNM Campus Tlalpan.
class ServicesConfig {
  static const _campusBaseUrl = 'https://www.tlalpan.tecnm.mx/';

  /// Get important services for the main tab
  static List<ImportantServiceModel> getImportantServices(
    BuildContext context,
  ) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      ImportantServiceModel(
        title: 'Mapa',
        description: 'Consulta la distribución y los espacios del campus.',
        iconData: Icons.map_rounded,
        color: colors.colorful02,
        isComingSoon: true,
      ),
    ];
  }

  /// Get communities
  static List<CommunityModel> getCommunities(BuildContext context) {
    return const [
      CommunityModel(
        title: 'Sitio oficial del campus',
        description: 'Página institucional del TecNM Campus Tlalpan.',
        url: _campusBaseUrl,
        logoUrl: 'https://www.tlalpan.tecnm.mx/img/logoitt.png',
      ),
      CommunityModel(
        title: 'Facebook oficial',
        description: 'Noticias, comunicados y publicaciones del campus.',
        url: 'https://www.facebook.com/tecnm.campus.tlalpan',
        logoUrl: 'https://www.tlalpan.tecnm.mx/img/logoitt.png',
      ),
      CommunityModel(
        title: 'Instagram oficial',
        description: 'Contenido institucional y actividades estudiantiles.',
        url: 'https://www.instagram.com/tecnmtlalpan/',
        logoUrl: 'https://www.tlalpan.tecnm.mx/img/logoitt.png',
      ),
    ];
  }

  /// Get banners for the "Digital University" tab
  static List<BannerModel> getBanners(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      BannerModel(
        title: 'SII Tlalpan',
        description:
            'Accede al sistema institucional de información del campus.',
        iconData: Icons.account_circle_rounded,
        color: colors.colorful03,
        url: 'https://siitlalpan.appspot.com/',
        action: 'Abrir',
      ),
      BannerModel(
        title: 'Portal estudiantil',
        description:
            'Accede a recursos e información útil para estudiantes del campus.',
        iconData: Icons.school_rounded,
        color: colors.colorful05,
        url: _campusBaseUrl,
        action: 'Consultar',
      ),
      BannerModel(
        title: 'Calendario académico',
        description: 'Consulta fechas importantes del periodo escolar.',
        iconData: Icons.event_note_rounded,
        color: colors.colorful01,
        url: _campusBaseUrl,
        action: 'Ver',
      ),
    ];
  }

  /// Get main services for the "Digital University" tab
  static List<ServiceTileModel> getMainServices(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      ServiceTileModel(
        title: 'SII',
        iconData: Icons.person_rounded,
        color: colors.colorful03,
        url: 'https://siitlalpan.appspot.com/',
      ),
      ServiceTileModel(
        title: 'Oferta educativa',
        iconData: Icons.school_rounded,
        color: colors.colorful05,
        url: _campusBaseUrl,
      ),
      ServiceTileModel(
        title: 'Servicio social',
        iconData: Icons.volunteer_activism_rounded,
        color: colors.colorful04,
        url: _campusBaseUrl,
      ),
      ServiceTileModel(
        title: 'Bolsa de trabajo',
        iconData: Icons.work_rounded,
        color: colors.colorful06,
        url: _campusBaseUrl,
      ),
      ServiceTileModel(
        title: 'Lenguas extranjeras',
        iconData: Icons.language_rounded,
        color: colors.colorful07,
        url: _campusBaseUrl,
      ),
      ServiceTileModel(
        title: 'Financieros',
        iconData: Icons.payments_outlined,
        color: colors.colorful05,
        url: _campusBaseUrl,
      ),
      ServiceTileModel(
        title: 'Comunicados',
        iconData: Icons.campaign_rounded,
        color: colors.colorful01,
        url: _campusBaseUrl,
      ),
    ];
  }

  /// Get student life services
  static List<HorizontalServiceModel> getStudentLifeServices(
    BuildContext context,
  ) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      HorizontalServiceModel(
        title: 'Residencias profesionales',
        description: 'Información de vinculación y residencias profesionales.',
        iconData: Icons.business_center_rounded,
        color: colors.colorful02,
        url: _campusBaseUrl,
      ),
      HorizontalServiceModel(
        title: 'Servicio social',
        description: 'Consulta información para liberar tu servicio social.',
        iconData: Icons.groups_rounded,
        color: colors.colorful04,
        url: _campusBaseUrl,
      ),
      HorizontalServiceModel(
        title: 'Buzón de sugerencias',
        description: 'Envía quejas, sugerencias o comentarios al campus.',
        iconData: Icons.mark_email_unread_rounded,
        color: colors.colorful06,
        url: _campusBaseUrl,
      ),
    ];
  }

  /// Get useful services
  static List<WideServiceModel> getUsefulServices(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return [
      WideServiceModel(
        title: 'Directorio institucional',
        description:
            'Consulta áreas administrativas y datos de contacto del campus.',
        iconData: Icons.contact_phone_rounded,
        color: colors.colorful01,
        url: _campusBaseUrl,
      ),
      WideServiceModel(
        title: 'Convocatoria nuevo ingreso',
        description: 'Información para aspirantes y procesos de admisión.',
        iconData: Icons.assignment_rounded,
        color: colors.colorful04,
        url: _campusBaseUrl,
      ),
      WideServiceModel(
        title: 'Contacto del campus',
        description:
            'Cerrada Santa Cruz #4, Predio Tetenco, Topilejo, Tlalpan, CDMX.',
        iconData: Icons.location_on_rounded,
        color: colors.colorful06,
        url: _campusBaseUrl,
      ),
    ];
  }
}
