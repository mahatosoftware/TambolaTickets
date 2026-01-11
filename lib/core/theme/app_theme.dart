import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color royalBlue = Color(0xFF1A237E); // Deep Royal Blue
  static const Color maroon = Color(0xFF880E4F); // Rich Maroon
  static const Color emeraldGreen = Color(0xFF1B5E20); // Deep Emerald
  static const Color gold = Color(0xFFFFD700); // Bright Gold
  static const Color goldDark = Color(0xFFC5A000); // Muted Gold for accents

  // Text Colors
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFFF5F5F5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: royalBlue,
        primary: royalBlue,
        secondary: maroon,
        tertiary: emeraldGreen,
        background: Colors.grey[50],
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.grey[50],
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: textDark,
        displayColor: textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // cardTheme: CardTheme(
      //   elevation: 2,
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      //   color: Colors.white,
      // ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: royalBlue,
        brightness: Brightness.dark,
        primary: const Color(0xFF536DFE), // Lighter royal blue for dark mode
        secondary: const Color(0xFFF06292), // Lighter maroon
        tertiary: const Color(0xFF69F0AE), // Lighter emerald
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF536DFE),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // cardTheme: CardTheme(
      //   elevation: 2,
      //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      //   color: const Color(0xFF1E1E1E),
      // ),
    );
  }
}
