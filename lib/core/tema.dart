import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cores do design system "Clinical Warmth & Human Clarity" (Stitch).
abstract final class Cores {
  static const primaria = Color(0xFF00685F);
  static const primariaContainer = Color(0xFF008378);
  static const teal = Color(0xFF0D9488);
  static const tealTexto = Color(0xFF0F766E);
  static const menta = Color(0xFF89F5E7);
  static const mentaSuave = Color(0xFFE6FBF7);
  static const ardosia = Color(0xFF0F172A);
  static const secundaria = Color(0xFF565E74);
  static const secundariaContainer = Color(0xFFDAE2FD);

  static const fundo = Color(0xFFF7F9FB);
  static const superficie = Color(0xFFFFFFFF);
  static const containerBaixo = Color(0xFFF2F4F6);
  static const container = Color(0xFFECEEF0);
  static const containerAlto = Color(0xFFE6E8EA);
  static const texto = Color(0xFF191C1E);
  static const textoSuave = Color(0xFF3D4947);
  static const contorno = Color(0xFF6D7A77);
  static const contornoSuave = Color(0xFFBCC9C6);
  static const borda = Color(0x0F0F172A); // rgba(15,23,42,0.06)
  static const bordaInput = Color(0xFFCBD5E1);
  static const divisor = Color(0xFFF1F5F9);

  // Semânticas
  static const sucesso = Color(0xFF10B981);
  static const sucessoFundo = Color(0xFFECFDF5);
  static const sucessoTexto = Color(0xFF065F46);
  static const alerta = Color(0xFFF59E0B);
  static const alertaFundo = Color(0xFFFFFBEB);
  static const alertaTexto = Color(0xFF92400E);
  static const erro = Color(0xFFEF4444);
  static const erroForte = Color(0xFFBA1A1A);
  static const erroFundo = Color(0xFFFEF2F2);
  static const erroTexto = Color(0xFF991B1B);
}

abstract final class Sombras {
  static const nivel1 = [
    BoxShadow(
      color: Color(0x0A0F172A),
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x050F172A),
      offset: Offset(0, 1),
      blurRadius: 4,
      spreadRadius: -1,
    ),
  ];
  static const nivel2 = [
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];
}

/// Tema do app. Em testes passamos [fontesWeb] = false para não baixar fontes.
class TemaApp {
  static bool fontesWeb = true;

  static TextStyle titulo({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color color = Cores.texto,
    double? height,
    double letterSpacing = 0,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
    return fontesWeb ? GoogleFonts.plusJakartaSans(textStyle: base) : base;
  }

  static TextStyle corpo({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Cores.texto,
    double? height,
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
    return fontesWeb
        ? GoogleFonts.atkinsonHyperlegibleNext(textStyle: base)
        : base;
  }

  static ThemeData claro() {
    final esquema = ColorScheme.fromSeed(
      seedColor: Cores.primaria,
      primary: Cores.primaria,
      onPrimary: Colors.white,
      primaryContainer: Cores.primariaContainer,
      secondary: Cores.secundaria,
      secondaryContainer: Cores.secundariaContainer,
      tertiary: Cores.teal,
      surface: Cores.fundo,
      error: Cores.erroForte,
    );

    final textos = TextTheme(
      headlineLarge: titulo(size: 32, height: 1.25, letterSpacing: -0.6),
      headlineMedium: titulo(size: 26, height: 1.3, letterSpacing: -0.3),
      headlineSmall: titulo(size: 24, height: 1.33, letterSpacing: -0.2),
      titleLarge: titulo(size: 20, weight: FontWeight.w600, height: 1.4),
      titleMedium: titulo(size: 18, weight: FontWeight.w600, height: 1.33),
      titleSmall: titulo(size: 16, weight: FontWeight.w600),
      bodyLarge: corpo(size: 16, height: 1.5),
      bodyMedium: corpo(size: 14, height: 1.43),
      bodySmall: corpo(size: 12, height: 1.33, color: Cores.textoSuave),
      labelLarge: corpo(size: 14, weight: FontWeight.w600),
      labelMedium: corpo(size: 12, weight: FontWeight.w600),
      labelSmall: corpo(size: 11, weight: FontWeight.w500),
    );

    final bordaInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Cores.bordaInput),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: Cores.fundo,
      textTheme: textos,
      appBarTheme: AppBarTheme(
        backgroundColor: Cores.superficie,
        foregroundColor: Cores.texto,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: titulo(size: 18, weight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Cores.superficie,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: bordaInput,
        enabledBorder: bordaInput,
        focusedBorder: bordaInput.copyWith(
          borderSide: const BorderSide(color: Cores.teal, width: 2),
        ),
        labelStyle: corpo(color: Cores.textoSuave),
        hintStyle: corpo(color: Cores.contorno),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Cores.primaria,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: corpo(size: 15, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Cores.tealTexto,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Cores.teal, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: corpo(size: 14, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Cores.primaria,
          textStyle: corpo(size: 14, weight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Cores.superficie,
        indicatorColor: Cores.mentaSuave,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => corpo(
            size: 12,
            weight: FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? Cores.primaria
                : Cores.textoSuave,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? Cores.primaria
                : Cores.textoSuave,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: Cores.borda),
        labelStyle: corpo(size: 13, weight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Cores.ardosia,
        contentTextStyle: corpo(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(color: Cores.divisor, space: 1),
    );
  }
}
