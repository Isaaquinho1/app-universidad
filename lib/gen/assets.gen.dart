/// GENERATED CODE - DO NOT MODIFY BY HAND
/// *****************************************************
///  FlutterGen
/// *****************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: directives_ordering,unnecessary_import,implicit_dynamic_list_literal,deprecated_member_use

import 'package:flutter/widgets.dart';

class $AssetsBrandingGen {
  const $AssetsBrandingGen();

  /// File path: assets/branding/conecta_itt_adaptive_foreground.png
  AssetGenImage get conectaIttAdaptiveForeground => const AssetGenImage(
      'assets/branding/conecta_itt_adaptive_foreground.png');

  /// File path: assets/branding/conecta_itt_app_icon.png
  AssetGenImage get conectaIttAppIcon =>
      const AssetGenImage('assets/branding/conecta_itt_app_icon.png');

  /// File path: assets/branding/conecta_itt_logo.png
  AssetGenImage get conectaIttLogo =>
      const AssetGenImage('assets/branding/conecta_itt_logo.png');

  /// File path: assets/branding/conecta_itt_logo_clean.png
  AssetGenImage get conectaIttLogoClean =>
      const AssetGenImage('assets/branding/conecta_itt_logo_clean.png');

  /// File path: assets/branding/conecta_itt_logo_source.png
  AssetGenImage get conectaIttLogoSource =>
      const AssetGenImage('assets/branding/conecta_itt_logo_source.png');

  /// File path: assets/branding/conecta_itt_splash_android12.png
  AssetGenImage get conectaIttSplashAndroid12 =>
      const AssetGenImage('assets/branding/conecta_itt_splash_android12.png');

  /// List of all assets
  List<AssetGenImage> get values => [
        conectaIttAdaptiveForeground,
        conectaIttAppIcon,
        conectaIttLogo,
        conectaIttLogoClean,
        conectaIttLogoSource,
        conectaIttSplashAndroid12
      ];
}

class $AssetsCampusGen {
  const $AssetsCampusGen();

  /// File path: assets/campus/campus_amanecer.png
  AssetGenImage get campusAmanecer =>
      const AssetGenImage('assets/campus/campus_amanecer.png');

  /// File path: assets/campus/campus_casi_noche.png
  AssetGenImage get campusCasiNoche =>
      const AssetGenImage('assets/campus/campus_casi_noche.png');

  /// File path: assets/campus/campus_lloviendo.png
  AssetGenImage get campusLloviendo =>
      const AssetGenImage('assets/campus/campus_lloviendo.png');

  /// File path: assets/campus/campus_madrugada.png
  AssetGenImage get campusMadrugada =>
      const AssetGenImage('assets/campus/campus_madrugada.png');

  /// File path: assets/campus/campus_medio_dia.png
  AssetGenImage get campusMedioDia =>
      const AssetGenImage('assets/campus/campus_medio_dia.png');

  /// File path: assets/campus/campus_neblina_casi_noche.png
  AssetGenImage get campusNeblinaCasiNoche =>
      const AssetGenImage('assets/campus/campus_neblina_casi_noche.png');

  /// File path: assets/campus/campus_noche.png
  AssetGenImage get campusNoche =>
      const AssetGenImage('assets/campus/campus_noche.png');

  /// File path: assets/campus/campus_nublado.png
  AssetGenImage get campusNublado =>
      const AssetGenImage('assets/campus/campus_nublado.png');

  /// File path: assets/campus/campus_super_nublado.png
  AssetGenImage get campusSuperNublado =>
      const AssetGenImage('assets/campus/campus_super_nublado.png');

  /// File path: assets/campus/campus_tarde.png
  AssetGenImage get campusTarde =>
      const AssetGenImage('assets/campus/campus_tarde.png');

  /// List of all assets
  List<AssetGenImage> get values => [
        campusAmanecer,
        campusCasiNoche,
        campusLloviendo,
        campusMadrugada,
        campusMedioDia,
        campusNeblinaCasiNoche,
        campusNoche,
        campusNublado,
        campusSuperNublado,
        campusTarde
      ];
}

class Assets {
  Assets._();

  static const $AssetsBrandingGen branding = $AssetsBrandingGen();
  static const $AssetsCampusGen campus = $AssetsCampusGen();
}

class AssetGenImage {
  const AssetGenImage(this._assetName);

  final String _assetName;

  Image image({
    Key? key,
    AssetBundle? bundle,
    ImageFrameBuilder? frameBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? scale,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = false,
    bool isAntiAlias = false,
    String? package,
    FilterQuality filterQuality = FilterQuality.low,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.asset(
      _assetName,
      key: key,
      bundle: bundle,
      frameBuilder: frameBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      scale: scale,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      isAntiAlias: isAntiAlias,
      package: package,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );
  }

  ImageProvider provider({
    AssetBundle? bundle,
    String? package,
  }) {
    return AssetImage(
      _assetName,
      bundle: bundle,
      package: package,
    );
  }

  String get path => _assetName;

  String get keyName => _assetName;
}
