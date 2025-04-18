import 'package:flutter/material.dart';
import '../ui/themes/app_themes.dart'; // Adjust path if needed

class ThemeProvider with ChangeNotifier {
  ThemeData _currentTheme = AppThemes.darkTheme; // Start with dark theme

  ThemeData get currentTheme => _currentTheme;

  bool get isDarkMode => _currentTheme == AppThemes.darkTheme;
  bool get isFantasyMode => _currentTheme == AppThemes.fantasyTheme;


  void setTheme(ThemeData theme) {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      notifyListeners();
    }
  }

  void toggleFantasyTheme() {
    if (_currentTheme == AppThemes.fantasyTheme) {
      setTheme(AppThemes.darkTheme); // Toggle back to dark if already fantasy
    } else {
      setTheme(AppThemes.fantasyTheme);
    }
  }
}