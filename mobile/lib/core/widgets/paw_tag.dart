import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_icon.dart';

/// "Etiqueta" de Figma: píldora 12 px Semi Bold en Plum. Lavanda por defecto
/// (PostType, CategoryTag); Butter/Mint/Cream según contexto.
class PawTag extends StatelessWidget {
  const PawTag(this.label, {super.key, this.background = PawColors.lavender});

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: PawSpacing.s12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(PawRadius.pill)),
      child: Text(label, style: PawText.tag),
    );
  }
}

/// Variante seleccionable de la etiqueta para elegir categorías.
/// Seleccionada: lavanda con check; sin seleccionar: blanca con borde. El estado no depende solo del color.
class PawChoiceTag extends StatelessWidget {
  const PawChoiceTag({super.key, required this.label, required this.selected, required this.onChanged});

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? PawColors.lavender : PawColors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? PawColors.lavender : PawColors.borderSubtle)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PawSizes.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PawSpacing.s12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[const PawIcon(PawIcons.check, size: 14), const SizedBox(width: 6)],
                  Text(label, style: PawText.tag),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
