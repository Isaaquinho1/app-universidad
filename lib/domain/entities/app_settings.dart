class AppSettings {
  final bool onboardingShown;
  final String lastUpdateVersion;
  final String theme;

  const AppSettings({
    required this.onboardingShown,
    required this.lastUpdateVersion,
    required this.theme,
  });

  factory AppSettings.defaultSettings() {
    return const AppSettings(
      onboardingShown: false,
      lastUpdateVersion: '',
      theme: 'system',
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      onboardingShown: json['onboardingShown'] as bool? ?? false,
      lastUpdateVersion: json['lastUpdateVersion'] as String? ?? '',
      theme: json['theme'] as String? ?? 'system',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'onboardingShown': onboardingShown,
      'lastUpdateVersion': lastUpdateVersion,
      'theme': theme,
    };
  }

  AppSettings copyWith({
    bool? onboardingShown,
    String? lastUpdateVersion,
    String? theme,
  }) {
    return AppSettings(
      onboardingShown: onboardingShown ?? this.onboardingShown,
      lastUpdateVersion: lastUpdateVersion ?? this.lastUpdateVersion,
      theme: theme ?? this.theme,
    );
  }
}
