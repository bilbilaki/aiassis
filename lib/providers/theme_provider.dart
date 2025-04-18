import 'package:flutter/material.dart';
import '../ui/themes/app_themes.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = AppThemes.darkTheme;

  ThemeData get currentTheme => _currentTheme;
  bool get isFantasyMode => _currentTheme == AppThemes.fantasyTheme;

  void setTheme(ThemeData theme) {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      notifyListeners();
    }
  }

  void toggleFantasyTheme() {
    if (_currentTheme == AppThemes.fantasyTheme) {
      setTheme(AppThemes.darkTheme);
    } else {
      setTheme(AppThemes.fantasyTheme);
    }
  }
}
