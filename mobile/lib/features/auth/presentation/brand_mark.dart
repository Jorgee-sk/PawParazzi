import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_icon.dart';

/// "Marca reducida" de Figma: símbolo 72 px (Plum, radio 24, huella blanca) + logotipo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PawParazzi',
      header: true,
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: PawColors.plum, borderRadius: BorderRadius.circular(PawRadius.r24)),
            alignment: Alignment.center,
            child: const PawIcon(PawIcons.pawPrintWhite40, size: 40),
          ),
          const SizedBox(width: PawSpacing.s16),
          const Text('PawParazzi', style: PawText.heading24),
        ],
      ),
    );
  }
}
