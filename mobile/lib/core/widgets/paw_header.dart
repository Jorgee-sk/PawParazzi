import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_icon.dart';

/// PawParazzi/Header · Type=Brand (68 px).
class PawBrandHeader extends StatelessWidget {
  const PawBrandHeader({super.key, this.title = 'PawParazzi', this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PawSizes.header,
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: PawText.heading24))),
          ?trailing,
        ],
      ),
    );
  }
}

/// PawParazzi/Header · Type=Detail (68 px): volver, título y acción opcional.
class PawDetailHeader extends StatelessWidget {
  const PawDetailHeader({super.key, required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PawSizes.header,
      child: Row(
        children: [
          PawIconButton(
            asset: PawIcons.arrowLeft,
            semanticLabel: 'Volver',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: PawSpacing.s4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: PawText.heading20, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Icono táctil de 44 px (área mínima del contrato de accesibilidad).
class PawIconButton extends StatelessWidget {
  const PawIconButton({
    super.key,
    required this.asset,
    required this.semanticLabel,
    required this.onPressed,
    this.background,
  });

  final String asset;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: background ?? Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: PawSizes.touchTarget,
            child: Center(child: PawIcon(asset)),
          ),
        ),
      ),
    );
  }
}
