import 'package:flutter/material.dart';

import 'tokens.dart';

/// Estilos tipográficos de Figma (PawParazzi/...). Manrope para títulos; Inter para texto.
abstract final class PawText {
  static const _manrope = 'Manrope';
  static const _inter = 'Inter';

  // Display / Heading — Manrope Bold, interlineado 1,18
  static const display40 = TextStyle(
      fontFamily: _manrope, fontSize: 40, fontWeight: FontWeight.w700, height: 1.18, color: PawColors.textPrimary);
  static const display32 = TextStyle(
      fontFamily: _manrope, fontSize: 32, fontWeight: FontWeight.w700, height: 1.18, color: PawColors.textPrimary);
  static const display28 = TextStyle(
      fontFamily: _manrope, fontSize: 28, fontWeight: FontWeight.w700, height: 1.18, color: PawColors.textPrimary);
  static const heading24 = TextStyle(
      fontFamily: _manrope, fontSize: 24, fontWeight: FontWeight.w700, height: 1.18, color: PawColors.textPrimary);
  static const heading22 = TextStyle(
      fontFamily: _manrope, fontSize: 22, fontWeight: FontWeight.w700, height: 1.18, color: PawColors.textPrimary);

  /// Logotipo "PawParazzi" (Manrope ExtraBold 26, Plum).
  static const logo = TextStyle(fontFamily: _manrope, fontSize: 26, fontWeight: FontWeight.w800, color: PawColors.plum);

  // Inter, interlineado 1,4
  static const heading20 = TextStyle(
      fontFamily: _inter, fontSize: 20, fontWeight: FontWeight.w700, height: 1.4, color: PawColors.textPrimary);
  static const title18 = TextStyle(
      fontFamily: _inter, fontSize: 18, fontWeight: FontWeight.w700, height: 1.4, color: PawColors.textPrimary);
  static const title18Semi = TextStyle(
      fontFamily: _inter, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: PawColors.textPrimary);
  static const title17 = TextStyle(
      fontFamily: _inter, fontSize: 17, fontWeight: FontWeight.w400, height: 1.4, color: PawColors.textMuted);
  static const body15 = TextStyle(
      fontFamily: _inter, fontSize: 15, fontWeight: FontWeight.w400, height: 1.4, color: PawColors.textPrimary);
  static const body15Semi = TextStyle(
      fontFamily: _inter, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4, color: PawColors.textPrimary);
  static const body14 = TextStyle(
      fontFamily: _inter, fontSize: 14, fontWeight: FontWeight.w400, height: 1.4, color: PawColors.textPrimary);
  static const caption13 = TextStyle(
      fontFamily: _inter, fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: PawColors.textMuted);
  static const caption13Semi = TextStyle(
      fontFamily: _inter, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4, color: PawColors.textPrimary);
  static const caption12 = TextStyle(
      fontFamily: _inter, fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, color: PawColors.textMuted);

  // Interlineado "normal" (100%) en controles
  static const button = TextStyle(fontFamily: _inter, fontSize: 15, fontWeight: FontWeight.w600);
  static const tag = TextStyle(fontFamily: _inter, fontSize: 12, fontWeight: FontWeight.w600, color: PawColors.plum);
  static const meta13 = TextStyle(fontFamily: _inter, fontSize: 13, fontWeight: FontWeight.w400, color: PawColors.plum);
  static const navActive = TextStyle(fontFamily: _inter, fontSize: 11, fontWeight: FontWeight.w700, color: PawColors.plum);
  static const navInactive =
      TextStyle(fontFamily: _inter, fontSize: 11, fontWeight: FontWeight.w500, color: PawColors.textMuted);
  static const avatarInitials14 =
      TextStyle(fontFamily: _manrope, fontSize: 14, fontWeight: FontWeight.w700, color: PawColors.plum);
  static const avatarInitials28 =
      TextStyle(fontFamily: _manrope, fontSize: 28, fontWeight: FontWeight.w700, color: PawColors.plum);
}
