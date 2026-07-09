import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rtu_mirea_app/schedule/widgets/mobile_map_view.dart'
    if (dart.library.html) 'package:rtu_mirea_app/schedule/widgets/web_map_view.dart';

/// Widget multiplataforma para mostrar el mapa
class CampusMapView extends StatelessWidget {
  /// Latitud del punto a mostrar
  final double latitude;

  /// Longitud del punto a mostrar
  final double longitude;

  const CampusMapView({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      return createMapView(latitude: latitude, longitude: longitude);
    } else {
      // En plataformas no compatibles se muestra un marcador
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Text('Los mapas solo están disponibles en dispositivos móviles', textAlign: TextAlign.center)),
      );
    }
  }
}
