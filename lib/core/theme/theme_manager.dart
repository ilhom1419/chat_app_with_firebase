import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeManager extends ChangeNotifier {
  static const _boxName = 'settingsBox';
  static const _themeKey = 'isDarkMode';
  late Box _box;

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    final isDark = _box.get(_themeKey, defaultValue: false) as bool;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await _box.put(_themeKey, isDark);
    notifyListeners();
  }
}
