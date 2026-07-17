import 'package:flutter/material.dart';

/// Theme global FarmBridge — satu sumber warna & bentuk untuk semua layar.
/// Sebelumnya app pakai `ColorScheme.fromSeed(Colors.green)` polos (default M3),
/// jadi tiap screen terlihat generik. Di sini brand-nya dikunci sekali.
class AppTheme {
  // Palet brand — forest green pekat (match desain FarmBridge), latar krem,
  // kartu putih murni. Token dipublikasikan supaya screen bisa reuse.
  static const Color brandGreen = Color(0xFF14532D); // primary: tombol, harga, emphasis
  static const Color leaf = Color(0xFF2E7D46); // aksen logo/ikon
  static const Color sage = Color(0xFFE7F2E9); // bg chip/badge/banner lembut
  static const Color cream = Color(0xFFF3F2E9); // latar scaffold
  static const Color ink = Color(0xFF1A2617); // teks utama

  static const Color _brandGreen = brandGreen;
  static const Color _brandGreenDark = brandGreen;
  static const Color _cream = cream;
  static const Color _surface = Colors.white; // kartu putih di atas krem
  static const Color _ink = ink;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _brandGreen,
      primary: _brandGreen,
      surface: _surface,
      onSurface: _ink,
    );

    final textTheme = Typography.blackMountainView
        .apply(bodyColor: _ink, displayColor: _ink)
        .copyWith(
          titleLarge: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: _ink),
          titleMedium: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: _ink),
          bodyMedium: const TextStyle(fontSize: 14, color: _ink, height: 1.35),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _cream,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: _cream,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: _brandGreenDark),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandGreen,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: _brandGreen),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brandGreen, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _brandGreen.withValues(alpha: 0.08),
        side: BorderSide.none,
        labelStyle: const TextStyle(
            color: _brandGreenDark, fontWeight: FontWeight.w600, fontSize: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: _brandGreen.withValues(alpha: 0.14),
        elevation: 3,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _brandGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 3,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.06),
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
