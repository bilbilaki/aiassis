// lib/themes.dart
import 'package:flutter/material.dart';

// --- Light Theme ---
final ThemeData lightTheme = ThemeData(
 useMaterial3: true,
 brightness: Brightness.light,
 // Define ColorScheme for modern Flutter theming
 colorScheme: ColorScheme.fromSeed(
 seedColor: Colors.indigo, // Your primary seed color
 brightness: Brightness.light,
 ),
 // You can still override specific colors if needed
 // primarySwatch: Colors.indigo, // Less used with ColorScheme
 appBarTheme: AppBarTheme(
 backgroundColor: Colors.indigo[600],
 foregroundColor: Colors.white,
 ),
 // Define default styles for input decoration, buttons etc.
 inputDecorationTheme: InputDecorationTheme(
 filled: true,
 fillColor: Colors.grey[100],
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(25.0),
 borderSide: BorderSide.none,
 ),
 contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
 ),
 elevatedButtonTheme: ElevatedButtonThemeData(
 style: ElevatedButton.styleFrom(
 foregroundColor: Colors.white,
 backgroundColor: Colors.indigo, // Use primary color
 ),
 ),
 // Define chat bubble colors (will be overridden in the widget but good defaults)
 cardColor: Colors.white, // Background for input area
 // Set default background color
 scaffoldBackgroundColor: Colors.grey[100],
);


// --- Dark Theme ---
final ThemeData darkTheme = ThemeData(
 useMaterial3: true,
 brightness: Brightness.dark,
 // Define ColorScheme for dark theme
 colorScheme: ColorScheme.fromSeed(
 seedColor: Colors.indigo, // Use the same seed color
 brightness: Brightness.dark,
 // Adjust specific dark theme colors if needed
 primary: Colors.indigo[300], // Lighter primary for dark theme
 secondary: Colors.tealAccent[100],
 surface: Colors.grey[850], // Main dark background
 onSurface: Colors.grey[300], // Text on dark background
 // Define colors used for chat bubbles explicitly if needed
 surfaceVariant: Colors.grey[800], // AI Bubble background
 primaryContainer: Colors.indigo[800]?.withOpacity(0.8), // User Bubble background
 error: Colors.redAccent[100],
 onError: Colors.black,
 ),
 appBarTheme: AppBarTheme(
 backgroundColor: Colors.grey[900], // Darker app bar
 foregroundColor: Colors.grey[300], // Lighter text on app bar
 ),
 inputDecorationTheme: InputDecorationTheme(
 filled: true,
 fillColor: Colors.grey[700]?.withOpacity(0.5), // Darker input fill
 hintStyle: TextStyle(color: Colors.grey[500]),
 border: OutlineInputBorder(
 borderRadius: BorderRadius.circular(25.0),
 borderSide: BorderSide.none,
 ),
 contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
 ),
 elevatedButtonTheme: ElevatedButtonThemeData(
 style: ElevatedButton.styleFrom(
 foregroundColor: Colors.white,
 backgroundColor: Colors.indigo[300], // Lighter primary for buttons
 ),
 ),
 textButtonTheme: TextButtonThemeData(
 style: TextButton.styleFrom(
 foregroundColor: Colors.indigo[300] // Ensure text buttons are visible
 )
 ),
 iconButtonTheme: IconButtonThemeData(
 style: IconButton.styleFrom(
 foregroundColor: Colors.indigo[300] // Ensure icon buttons are visible often
 )
 ),
 popupMenuTheme: PopupMenuThemeData(
 color: Colors.grey[800], // Dark background for popup menus
 textStyle: TextStyle(color: Colors.grey[300]),
 ),
 chipTheme: ChipThemeData(
 backgroundColor: Colors.grey[700],
 labelStyle: TextStyle(color: Colors.white),
 ),
 // Default card color (used for input background usually)
 cardColor: Colors.grey[850],
 // Set default scaffold background
 scaffoldBackgroundColor: const Color(0xFF121212), // Common dark theme background
 listTileTheme: ListTileThemeData(
 selectedTileColor: Colors.indigo.withOpacity(0.2),
 textColor: Colors.grey[300],
 iconColor: Colors.grey[400]
 ),
 drawerTheme: DrawerThemeData(
 backgroundColor: Colors.grey[900]
 )
);