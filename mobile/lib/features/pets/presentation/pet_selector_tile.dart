import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_avatar.dart';
import '../../../core/widgets/paw_icon.dart';
import '../data/pet_models.dart';

/// PawParazzi/PetSelector (64 px). Selección múltiple explícita, nunca inferida:
/// seleccionada = borde Plum + check; sin seleccionar = borde sutil sin check.
class PetSelectorTile extends StatelessWidget {
  const PetSelectorTile({
    super.key,
    required this.pet,
    required this.subtitle,
    this.selected,
    this.onTap,
  });

  final Pet pet;
  final String subtitle;

  /// null: fila informativa (sin selección).
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected ?? false;
    return Semantics(
      selected: selected,
      button: onTap != null,
      label: '${pet.name}. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: PawColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PawRadius.r16),
          side: BorderSide(color: isSelected || selected == null ? PawColors.plum : PawColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(PawSpacing.s12),
            child: Row(
              children: [
                PetAvatar(name: pet.name, imageUrl: pet.photoThumbnailUrl, size: 40),
                const SizedBox(width: PawSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet.name, style: PawText.body15Semi),
                      Text(subtitle, style: PawText.caption12),
                    ],
                  ),
                ),
                if (selected != null)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: isSelected ? const PawIcon(PawIcons.circleCheck) : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
