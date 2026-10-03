import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPreferences {
  LocalPreferences._();

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _onboardingKey = 'onboarding_completed';
  static const _localeKey = 'preferred_locale';
  static const _themeKey = 'preferred_theme';

  static Future<bool> isOnboardingCompleted() async =>
      await _prefs.getBool(_onboardingKey) ?? false;

  static Future<void> completeOnboarding() =>
      _prefs.setBool(_onboardingKey, true);

  static Future<Locale> readLocale() async {
    final code = await _prefs.getString(_localeKey) ?? 'sq';
    const allowed = {'sq', 'en', 'fr', 'de', 'it'};
    return Locale(allowed.contains(code) ? code : 'sq');
  }

  static Future<void> saveLocale(Locale locale) =>
      _prefs.setString(_localeKey, locale.languageCode);

  static Future<ThemeMode> readThemeMode() async {
    final value = await _prefs.getString(_themeKey) ?? 'system';
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);
}