// Design tokens from docs/design-analysis.md ("Our design") and the approved mockups.
// The TV's logical screen is 1920x1080, so sizes are the mockups' pixels.
import 'package:flutter/material.dart';

class Palette {
  static const ground = Color(0xFF0B0D12);
  static const surface = Color(0xFF151922);
  static const surfaceRaised = Color(0xFF1D2230);
  static const field = Color(0xFF0F1218);
  static const fieldBorder = Color(0xFF2C3345);
  static const accent = Color(0xFF00A4DC);
  static const accentText = Color(0xFF4CC3EE);
  static const onAccent = Color(0xFF001B26);
  static const text = Colors.white;
  static const text2 = Color(0xB8FFFFFF); // 72%
  static const text3 = Color(0x8CFFFFFF); // 55%
  static const star = Color(0xFFF5C518);
  static const danger = Color(0xFFFF8A80);
  static const focusGlow = Color(0x7300A4DC); // accent at 45%
}

class Insets {
  static const page = 96.0; // left/right margin
  static const header = 120.0;
}

TextStyle tv(double size, {FontWeight weight = FontWeight.w400, Color color = Palette.text, double? height, double? spacing}) =>
    TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: 'Inter');
  return base.copyWith(
    scaffoldBackgroundColor: Palette.ground,
    colorScheme: base.colorScheme.copyWith(primary: Palette.accent, surface: Palette.surface),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Palette.accent),
    // No ink ripples on a TV: focus is shown by our own widgets.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    focusColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );
}

/// Ring, glow and lift of a focused element (the mockups' white ring with a blue halo).
List<BoxShadow> focusShadow({double ring = 4}) => [
      BoxShadow(color: Colors.white, spreadRadius: ring, blurRadius: 0),
      BoxShadow(color: Palette.focusGlow, spreadRadius: ring + 6, blurRadius: 0),
    ];
