import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_button.dart';
import 'paw_icon.dart';
import 'paw_message.dart';

/// PawParazzi/EmptyState: ilustración simbólica (96 px, radio 32, lavanda), título Manrope 24
/// y texto 15. Nunca se rellena con contenido inventado.
class PawEmptyState extends StatelessWidget {
  const PawEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: PawSpacing.s32),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: PawColors.lavender, borderRadius: BorderRadius.circular(32)),
          alignment: Alignment.center,
          child: PawIcon(icon, size: 44),
        ),
        const SizedBox(height: PawSpacing.s20),
        Text(title, style: PawText.heading24, textAlign: TextAlign.center),
        const SizedBox(height: PawSpacing.s20),
        Text(body, style: PawText.body15.copyWith(color: PawColors.textMuted), textAlign: TextAlign.center),
        const SizedBox(height: PawSpacing.s32),
        if (actionLabel != null) PawButton(label: actionLabel!, onPressed: onAction),
      ],
    );
  }
}

/// Error recuperable de carga: mensaje contextual + "Reintentar".
class PawErrorState extends StatelessWidget {
  const PawErrorState({super.key, required this.message, required this.onRetry, this.title = 'No pudimos cargar esto'});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PawMessage(icon: PawIcons.cloudOff, title: title, body: message),
        const SizedBox(height: PawSpacing.s16),
        PawButton.secondary(label: 'Reintentar', onPressed: onRetry),
      ],
    );
  }
}

/// Skeleton de publicación (Figma "Reserva de espacio"): dimensiones estables, sin destello.
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block(double? w, double h, double r) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: PawColors.surfaceTone2, borderRadius: BorderRadius.circular(r)),
        );
    return Semantics(
      label: 'Cargando publicación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const PawIcon(PawIcons.avatarPending, size: 40),
            const SizedBox(width: PawSpacing.s12),
            block(184, 16, PawRadius.r8),
          ]),
          const SizedBox(height: PawSpacing.s16),
          block(double.infinity, 244, PawRadius.r24),
          const SizedBox(height: PawSpacing.s16),
          block(240, 12, 6),
        ],
      ),
    );
  }
}

/// PawParazzi/ConfirmDialog. La acción destructiva siempre nombra lo que elimina.
Future<bool> showPawConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: PawColors.cream,
      insetPadding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PawRadius.r24)),
      child: Padding(
        padding: const EdgeInsets.all(PawSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: PawText.heading24),
            const SizedBox(height: PawSpacing.s16),
            Text(body, style: PawText.body15),
            const SizedBox(height: PawSpacing.s16),
            PawButton(label: confirmLabel, onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: PawSpacing.s16),
            PawButton.secondary(label: cancelLabel, onPressed: () => Navigator.of(context).pop(false)),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
