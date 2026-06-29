import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _darkModeKey = 'settings.dark_mode';
  static const _themeColorKey = 'settings.theme_color';
  static const _fontScaleKey = 'settings.font_scale';
  static const _languageKey = 'settings.language';

  bool _isDarkMode = false;
  String _themeColor = 'blue';
  double _fontScale = 1.0;
  String _language = 'fr';

  bool get isDarkMode => _isDarkMode;
  String get themeColor => _themeColor;
  double get fontScale => _fontScale;
  String get language => _language;
  bool get isLargeFont => _fontScale > 1.0;

  static const Map<String, String> colorLabels = {
    'blue': 'Bleu',
    'red': 'Rouge',
    'green': 'Vert',
    'purple': 'Violet',
    'orange': 'Orange',
  };

  static const Map<String, String> languageLabels = {
    'fr': 'Francais',
    'mg': 'Malagasy',
    'en': 'English',
  };

  static const Map<String, Map<String, String>> _texts = {
    'fr': {
      'settings': 'Parametres',
      'appearance': 'Apparence',
      'dark_mode': 'Mode sombre',
      'enabled': 'Active',
      'disabled': 'Desactive',
      'theme_color': 'Theme couleur',
      'large_font': 'Police agrandie',
      'large_font_on': 'Texte plus grand',
      'large_font_off': 'Taille normale',
      'language': 'Langue',
      'about': 'A propos',
      'description': 'Plateforme de forum pour la communaute.',
      'version': 'Version',
      'developer': 'Developpeur',
    },
    'mg': {
      'settings': 'Kirakira',
      'appearance': 'Endrika',
      'dark_mode': 'Maizina',
      'enabled': 'Mandeha',
      'disabled': 'Tsy mandeha',
      'theme_color': 'Loko fototra',
      'large_font': 'Soratra lehibe',
      'large_font_on': 'Soratra nohalehibeazina',
      'large_font_off': 'Habe mahazatra',
      'language': 'Fiteny',
      'about': 'Momba',
      'description': 'Sehatra fifanakalozan-kevitra ho an ny fiarahamonina.',
      'version': 'Dika',
      'developer': 'Mpamorona',
    },
    'en': {
      'settings': 'Settings',
      'appearance': 'Appearance',
      'dark_mode': 'Dark mode',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'theme_color': 'Theme color',
      'large_font': 'Larger font',
      'large_font_on': 'Larger text',
      'large_font_off': 'Normal size',
      'language': 'Language',
      'about': 'About',
      'description': 'Forum platform for the community.',
      'version': 'Version',
      'developer': 'Developer',
    },
  };

  ThemeData get themeData => _buildTheme(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      );

  String text(String key) {
    return _texts[_language]?[key] ?? _texts['fr']?[key] ?? key;
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    _themeColor = prefs.getString(_themeColorKey) ?? 'blue';
    _fontScale = prefs.getDouble(_fontScaleKey) ?? 1.0;
    _language = prefs.getString(_languageKey) ?? 'fr';
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> toggleTheme() => setDarkMode(!_isDarkMode);

  Future<void> setThemeColor(String value) async {
    if (!colorLabels.containsKey(value)) return;
    _themeColor = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, value);
  }

  Future<void> setLargeFont(bool value) async {
    _fontScale = value ? 1.18 : 1.0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontScaleKey, _fontScale);
  }

  Future<void> setLanguage(String value) async {
    if (!languageLabels.containsKey(value)) return;
    _language = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }

  ThemeData _buildTheme({required Brightness brightness}) {
    final seedColor = _seedColor(_themeColor);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor:
            brightness == Brightness.light ? colorScheme.primary : null,
        foregroundColor:
            brightness == Brightness.light ? colorScheme.onPrimary : null,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }

  Color _seedColor(String value) {
    switch (value) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'blue':
      default:
        return Colors.blue;
    }
  }
}
