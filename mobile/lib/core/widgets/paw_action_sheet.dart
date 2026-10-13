import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class PawSheetAction {
  const PawSheetAction({required this.label, required this.onSelected, this.subtitle, this.destructive = false});

  final String label;
  final String? subtitle;

  /// Acción destructiva: se muestra en el color de error (además de nombrar lo que hace).
  final bool destructive;
  final VoidCallback onSelected;
}

/// Menú de opciones en hoja inferior. Cada acción se ejecuta después de cerrar la hoja.
Future<void> showPawActionSheet(BuildContext context, List<PawSheetAction> actions) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: PawColors.cream,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PawSpacing.screen, 0, PawSpacing.screen, PawSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: PawSizes.button,
                title: Text(
                  action.label,
                  style: PawText.body15Semi.copyWith(color: action.destructive ? PawColors.error : null),
                ),
                subtitle: action.subtitle == null ? null : Text(action.subtitle!, style: PawText.caption13),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  action.onSelected();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
