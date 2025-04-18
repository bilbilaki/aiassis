import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF1E1E1E),
    primaryColor: const Color(0xFF8C61FF), // Primary accent
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF8C61FF), // Used by ElevatedButton, FloatingActionButton etc.
      secondary: Color(0xFF8C61FF), // Accent color
      background: Color(0xFF1E1E1E), // Background of cards, dialogs etc.
      surface: Color(0xFF252525), // Surfaces like AppBar, Card background
      onPrimary: Colors.white, // Text/icons on primary color
      onSecondary: Colors.white, // Text/icons on secondary color
      onBackground: Colors.white, // Text/icons on background color
      onSurface: Colors.white, // Text/icons on surface color
      error: Colors.redAccent,
      onError: Colors.white,
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF252525),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: GoogleFonts.inter(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF333333),
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF8C61FF), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8C61FF), // Button background
        foregroundColor: Colors.white, // Button text/icon color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      bodyMedium: GoogleFonts.inter(color: Colors.white, fontSize: 14, height: 1.5),
      titleMedium: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
      labelSmall: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
    ).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    dividerColor: Colors.grey.shade800,
    listTileTheme: ListTileThemeData(
      iconColor: Colors.grey.shade400,
      titleTextStyle: GoogleFonts.inter(fontSize: 14),
      subtitleTextStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
    ),
     chipTheme: ChipThemeData(
       backgroundColor: const Color(0xFF333333),
       labelStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(16),
         side: BorderSide(color: Colors.grey.shade700),
       ),
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
     ),
  );

  // --- Fantasy Theme Definition ---
  static final ThemeData fantasyTheme = ThemeData.dark().copyWith(
     // Base Colors
     scaffoldBackgroundColor: const Color(0xFF1A0A2A), // Deep purple/indigo background
     primaryColor: const Color(0xFFE040FB), // Vibrant Magenta/Pink
     hintColor: const Color(0xFF00E5FF), // Bright Cyan for accents/hints

     colorScheme: const ColorScheme.dark(
       primary: Color(0xFFE040FB),         // Magenta
       secondary: Color(0xFF00E5FF),        // Cyan accent
       background: Color(0xFF1A0A2A),      // Deep Purple bg
       surface: Color(0xFF2E1C41),         // Darker purple surface
       onPrimary: Colors.black,            // Text on Magenta (consider contrast)
       onSecondary: Colors.black,          // Text on Cyan
       onBackground: Color(0xFFE6E0FF),     // Light Lavender text on bg
       onSurface: Color(0xFFE6E0FF),        // Light Lavender text on surface
       error: Color(0xFFFF5252),           // Bright Red error
       onError: Colors.black,
       brightness: Brightness.dark,
     ),

     appBarTheme: AppBarTheme(
       backgroundColor: const Color(0xFF2E1C41), // Darker purple AppBar
       elevation: 2,
       shadowColor: Colors.black.withOpacity(0.5),
       iconTheme: const IconThemeData(color: Color(0xFF00E5FF)), // Cyan icons
       titleTextStyle: GoogleFonts.cinzelDecorative( // Fantasy font
           color: const Color(0xFFE6E0FF), fontSize: 20, fontWeight: FontWeight.bold,
           shadows: [Shadow(blurRadius: 4.0, color: Color(0xFFE040FB).withOpacity(0.5), offset: Offset(1,1))]
         ),
     ),

     inputDecorationTheme: InputDecorationTheme(
       filled: true,
       fillColor: const Color(0xFF3A2650), // Slightly lighter purple input bg
       hintStyle: GoogleFonts.lato(color: Color(0xFF00E5FF).withOpacity(0.7)), // Cyan hint
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(20), // Rounded corners
         borderSide: BorderSide(color: Color(0xFFE040FB).withOpacity(0.5)),
       ),
       enabledBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(20),
         borderSide: BorderSide(color: Color(0xFFE040FB).withOpacity(0.5)),
       ),
       focusedBorder: OutlineInputBorder(
         borderRadius: BorderRadius.circular(20),
         borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2), // Cyan focus border
       ),
     ),

     elevatedButtonTheme: ElevatedButtonThemeData(
       style: ElevatedButton.styleFrom(
         backgroundColor: const Color(0xFFE040FB), // Magenta button bg
         foregroundColor: Colors.black, // Black text on button
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(30), // Pill shaped
         ),
         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
         textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 15), // Another fantasy font
         elevation: 5,
         shadowColor: Colors.black.withOpacity(0.6),
       ),
     ),

     textTheme: TextTheme(
       bodyLarge: GoogleFonts.lato(color: const Color(0xFFE6E0FF), fontSize: 16),
       bodyMedium: GoogleFonts.lato(color: const Color(0xFFE6E0FF), fontSize: 14, height: 1.6),
       titleMedium: GoogleFonts.cinzel(color: const Color(0xFFE6E0FF), fontWeight: FontWeight.bold),
       labelSmall: GoogleFonts.lato(color: Color(0xFF00E5FF).withOpacity(0.8), fontSize: 12),
     ).apply(
       bodyColor: const Color(0xFFE6E0FF),
       displayColor: const Color(0xFFE6E0FF),
     ),

     iconTheme: const IconThemeData(color: Color(0xFF00E5FF)), // Cyan default icons
     dividerColor: Color(0xFFE040FB).withOpacity(0.3), // Faint Magenta divider

       listTileTheme: ListTileThemeData(
         iconColor: Color(0xFF00E5FF).withOpacity(0.8),
         titleTextStyle: GoogleFonts.lato(fontSize: 14, color: const Color(0xFFE6E0FF)),
         subtitleTextStyle: GoogleFonts.lato(fontSize: 12, color: Color(0xFF00E5FF).withOpacity(0.7)),
           selectedTileColor: Color(0xFFE040FB).withOpacity(0.2), // Selection highlight
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
       ),

     chipTheme: ChipThemeData(
       backgroundColor: Color(0xFF3A2650),
       labelStyle: GoogleFonts.lato(fontSize: 14, color: Color(0xFFE6E0FF)),
       shape: StadiumBorder( // Rounded chip
         side: BorderSide(color: Color(0xFFE040FB).withOpacity(0.6)),
       ),
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
     ),

     // Add specific overrides for Markdown, SyntaxHighlighter if needed
     // e.g., define custom styles in MarkdownStyleSheet using fantasy colors
  );
}