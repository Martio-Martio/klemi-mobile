import 'package:flutter/material.dart';

/// Charte graphique Klemi (version mobile claire) — voir le canvas de design.
class AppTheme {
  // Fonds
  static const Color beige = Color(0xFFF7F2E8);
  static const Color beigeClair = Color(0xFFFBF8F2);
  static const Color sable = Color(0xFFEFE8DA);
  static const Color blanc = Color(0xFFFFFFFF);
  static const Color bordure = Color(0xFFE6DDCC);
  static const Color bordurePointillee = Color(0xFFCFC4AE);

  // Textes
  static const Color navy = Color(0xFF0A3A5C);
  static const Color texteSecondaire = Color(0xFF5F6E7C);
  static const Color texteDiscret = Color(0xFF6F7D8A);
  static const Color texteCorps = Color(0xFF334A5E);

  // Accents de la charte Klemi
  static const Color bleu = Color(0xFF36AAF5); // actions principales
  static const Color bleuFonce = Color(0xFF026FC2);
  static const Color orange = Color(0xFFFD9C2B); // quiz
  static const Color orangeFonce = Color(0xFFB34E08);
  static const Color vert = Color(0xFF6AB39A); // fiches / succès
  static const Color vertFonce = Color(0xFF2E6353);
  static const Color vertClair = Color(0xFFE3F1EC);
  static const Color rouge = Color(0xFFF27575); // erreurs
  static const Color rougeFonce = Color(0xFFB91F1F);
  static const Color rougeClair = Color(0xFFFDE3E3);
  static const Color whatsapp = Color(0xFF25D366);
  static const Color bleuClair = Color(0xFFE0EEFE);

  // Anciennes constantes conservées pour EasyLoading / compatibilité
  static const Color couleurDefaut = navy;
  static final Color? couleurDefautLigth = Colors.grey[100];
  static const Color couleurDefautBackroungColorGris = beige;

  static const double radiusCarte = 18;
  static const double radiusChamp = 14;

  /// Lato ne dessine pas ɛ, ɔ, ɓ, ɗ ni ŋ. Cette famille ne sert que pour ces lettres.
  static const List<String> famillesSecours = ['NotoSansFallback'];

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: bleu,
      onPrimary: navy,
      secondary: orange,
      onSecondary: navy,
      error: rougeFonce,
      onError: blanc,
      surface: blanc,
      onSurface: navy,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: beige,
      fontFamily: 'Lato',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: navy,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: navy),
        bodyMedium: TextStyle(fontSize: 14, color: navy),
        bodySmall: TextStyle(fontSize: 12, color: texteDiscret),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blanc,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusChamp),
          borderSide: const BorderSide(color: bordure),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusChamp),
          borderSide: const BorderSide(color: bordure),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusChamp),
          borderSide: const BorderSide(color: bleu, width: 2),
        ),
        hintStyle: const TextStyle(color: texteDiscret),
      ),
      dividerColor: bordure,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
