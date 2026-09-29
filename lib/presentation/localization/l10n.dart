import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/widgets.dart';

import '../../application/layers/map_layer_controller.dart';
import '../../application/settings/app_language_controller.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// The editor strings for the active locale.
  ///
  /// Widgets hosted outside the localized app (isolated widget tests, tools)
  /// fall back to English instead of failing.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

/// The locale to force for [preference], or `null` to follow the system.
Locale? localeForLanguagePreference(AppLanguagePreference preference) {
  final code = preference.languageCode;
  return code == null ? null : Locale(code);
}

/// The shipped language the system locale resolves to.
AppLanguagePreference systemLanguage([PlatformDispatcher? dispatcher]) {
  final locales =
      (dispatcher ?? WidgetsBinding.instance.platformDispatcher).locales;
  for (final locale in locales) {
    if (locale.languageCode == 'ko') {
      return AppLanguagePreference.korean;
    }
    if (locale.languageCode == 'en') {
      return AppLanguagePreference.english;
    }
  }
  return AppLanguagePreference.english;
}

/// A language's own name, shown the same way in every UI language so a user
/// can always find their language.
String languageAutonym(AppLanguagePreference preference) =>
    switch (preference) {
      AppLanguagePreference.korean => '한국어',
      AppLanguagePreference.english => 'English',
      AppLanguagePreference.system => languageAutonym(systemLanguage()),
    };

extension MapLayerTypeLocalization on MapLayerType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    MapLayerType.terrain => l10n.layerTerrain,
    MapLayerType.locations => l10n.layerLocations,
    MapLayerType.doodads => l10n.layerDoodads,
    MapLayerType.sprites => l10n.layerSprites,
    MapLayerType.units => l10n.layerUnits,
  };
}
