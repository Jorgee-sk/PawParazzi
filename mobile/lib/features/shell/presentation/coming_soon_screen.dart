import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_tag.dart';

/// Pestañas previstas en el diseño cuya funcionalidad aún no existe (fase 2).
/// Se indica claramente que no están disponibles: no se simula contenido.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.body});

  final String title;
  final String icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
        children: [
          PawBrandHeader(title: title),
          const Align(alignment: Alignment.centerLeft, child: PawTag('Fase futura · no disponible', background: PawColors.butter)),
          PawEmptyState(icon: icon, title: 'Todavía no está disponible', body: body),
        ],
      ),
    );
  }
}
