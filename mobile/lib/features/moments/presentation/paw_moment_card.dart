import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_icon.dart';
import '../data/post_models.dart';

/// Estado del PawMoment de hoy. Construido con el patrón "Mensaje contextual" + Botón principal.
/// La ventana es informativa: en ningún estado se bloquea la publicación.
class PawMomentCard extends StatelessWidget {
  const PawMomentCard({super.key, required this.today, required this.onCapture});

  final TodayMoment today;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final start = hourMinute(today.windowStart);
    final end = hourMinute(today.windowEnd);
    final (icon, background, title, body) = today.participated
        ? (
            PawIcons.circleCheckToast,
            PawColors.mint,
            'PawMoment de hoy compartido',
            'Ya está en el feed de tus amigos. Puedes seguir compartiendo fotos libres.',
          )
        : switch (today.status) {
            MomentWindowStatus.upcoming => (
                PawIcons.zap,
                PawColors.lavender,
                'PawMoment de hoy a las $start',
                'Si te adelantas también cuenta; dentro de la ventana se marca "a tiempo".',
              ),
            MomentWindowStatus.open => (
                PawIcons.zap,
                PawColors.butter,
                '¡Es el momento! Hasta las $end',
                'Fotografía lo que esté haciendo tu mascota ahora mismo. Nada de posar.',
              ),
            MomentWindowStatus.late => (
                PawIcons.zap,
                PawColors.lavender,
                'La ventana pasó, pero aún cuenta',
                'Era de $start a $end. Publica tu PawMoment cuando puedas: suma a tu racha igual.',
              ),
          };

    return Container(
      padding: const EdgeInsets.all(PawSpacing.s16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(PawRadius.r20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PawIcon(icon, size: 24),
              const SizedBox(width: PawSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PawText.body15Semi),
                    Text(body, style: PawText.caption13),
                  ],
                ),
              ),
            ],
          ),
          if (!today.participated) ...[
            const SizedBox(height: PawSpacing.s16),
            PawButton(label: 'Capturar PawMoment', onPressed: onCapture),
          ],
        ],
      ),
    );
  }
}
