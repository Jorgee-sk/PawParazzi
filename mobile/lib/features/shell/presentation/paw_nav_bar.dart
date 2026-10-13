import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_icon.dart';

class PawNavItem {
  const PawNavItem(this.label, this.icon, this.activeIcon);

  final String label;
  final String icon;
  final String activeIcon;
}

/// PawParazzi/Navigation: cinco pestañas, la activa sobre lavanda y en Bold Plum.
/// "Capturar" mantiene un fondo crema cuando no está activa (protagonismo de la cámara).
class PawNavBar extends StatelessWidget {
  const PawNavBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const items = [
    PawNavItem('Inicio', PawIcons.navHome, PawIcons.navHomeActive),
    PawNavItem('Capturar', PawIcons.navCamera, PawIcons.navCameraActive),
    PawNavItem('Paw Hunt', PawIcons.navHunt, PawIcons.navHuntActive),
    PawNavItem('Grupos', PawIcons.navGroups, PawIcons.navGroupsActive),
    PawNavItem('Perfil', PawIcons.navProfile, PawIcons.navProfileActive),
  ];

  static const _captureIndex = 1;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: PawColors.white,
        border: Border(top: BorderSide(color: PawColors.borderSubtle)),
      ),
      padding: EdgeInsets.fromLTRB(PawSpacing.s12, PawSpacing.s8, PawSpacing.s12, bottomInset > 0 ? bottomInset : PawSpacing.s8),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(child: _tab(i)),
          ],
        ],
      ),
    );
  }

  Widget _tab(int i) {
    final item = items[i];
    final active = i == currentIndex;
    final background = active
        ? PawColors.lavender
        : i == _captureIndex
            ? PawColors.cream
            : PawColors.white;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(PawRadius.r16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(i),
          child: SizedBox(
            height: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: PawSpacing.s4),
              child: Column(
                children: [
                  PawIcon(active ? item.activeIcon : item.icon),
                  const SizedBox(height: PawSpacing.s4),
                  Text(
                    item.label,
                    style: active ? PawText.navActive : PawText.navInactive,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
