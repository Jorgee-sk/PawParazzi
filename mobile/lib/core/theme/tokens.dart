import 'package:flutter/material.dart';

/// Variables de color del archivo de Figma "01 · Marca & Sistema".
/// Los nombres reflejan la variable original (p. ej. `brand/plum`).
abstract final class PawColors {
  static const cream = Color(0xFFFFF8F0); // background/cream
  static const white = Color(0xFFFFFFFF); // surface/white
  static const plum = Color(0xFF573B52); // brand/plum
  static const coral = Color(0xFFFF796C); // accent/coral — flash y microacentos, nunca texto pequeño
  static const lavender = Color(0xFFE8DFFF); // support/lavender
  static const butter = Color(0xFFFFE5A3); // reward/butter
  static const mint = Color(0xFFCDEBDD); // positive/mint
  static const textPrimary = Color(0xFF29242B); // text/primary
  static const textMuted = Color(0xFF655A66); // text/tone-1 — metadatos (6,22:1 sobre cream)
  static const textSecondary = Color(0xFF817782); // text/secondary — no usar en texto pequeño
  static const borderSubtle = Color(0xFFEEE5EC); // border/subtle
  static const surfaceTone2 = Color(0xFFEDE5E9); // surface/tone-2 — skeleton
  static const surfaceTone3 = Color(0xFFDCD2DA); // surface/tone-3 — botón deshabilitado
  static const error = Color(0xFFA6373E); // surface/tone-4 — error de campo
  static const camera = Color(0xFF201B22); // surface/tone-5 — fondo del disparador
}

/// Escala de espaciado (Figma: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48).
abstract final class PawSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;

  /// Margen lateral móvil del contrato de diseño.
  static const screen = 24.0;
}

/// Radios: 16 entrada/botón · 20 mensaje · 24 foto.
abstract final class PawRadius {
  static const r8 = 8.0;
  static const r16 = 16.0;
  static const r20 = 20.0;
  static const r24 = 24.0;
  static const pill = 100.0;
}

abstract final class PawSizes {
  static const button = 52.0;
  static const buttonCompact = 44.0;
  static const touchTarget = 44.0;
  static const header = 68.0;
  static const navBar = 88.0;
  static const icon = 22.0;
}

abstract final class PawShadows {
  /// PawParazzi/Elevation/Subtle: #573B520C, (0, 4), blur 16.
  static const subtle = [
    BoxShadow(color: Color(0x0C573B52), offset: Offset(0, 4), blurRadius: 16),
  ];
}
