import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_icon.dart';

/// "Mensaje contextual" de Figma (ErrorMessage, Toast, información): icono 24, título 15 Semi Bold
/// y texto 13 opcional, radio 20, padding 16.
class PawMessage extends StatelessWidget {
  const PawMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.background = PawColors.lavender,
    this.trailing,
  });

  /// Toast "Foto publicada" (mint).
  const PawMessage.success({super.key, required this.title, this.body, this.trailing})
      : icon = PawIcons.circleCheckToast,
        background = PawColors.mint;

  final String icon;
  final String title;
  final String? body;
  final Color background;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PawSpacing.s16),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(PawRadius.r20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PawIcon(icon, size: 24),
          const SizedBox(width: PawSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: PawText.body15Semi),
                if (body != null) Text(body!, style: PawText.caption13),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: PawSpacing.s12), trailing!],
        ],
      ),
    );
  }
}

/// Toast breve (Figma: 2,5–4 s, accesible por lector de pantalla, no tapa la acción principal).
void showPawToast(BuildContext context, {required String title, String? body, bool success = true}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 3500),
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(PawSpacing.screen, 0, PawSpacing.screen, PawSpacing.s16),
      content: Semantics(
        liveRegion: true,
        child: body == null
            ? PawMessage(
                icon: success ? PawIcons.check : PawIcons.info,
                title: title,
                background: success ? PawColors.mint : PawColors.lavender,
              )
            : PawMessage(
                icon: success ? PawIcons.circleCheckToast : PawIcons.info,
                title: title,
                body: body,
                background: success ? PawColors.mint : PawColors.lavender,
              ),
      ),
    ));
}
