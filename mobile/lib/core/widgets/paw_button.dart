import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_icon.dart';

enum PawButtonVariant { primary, secondary }

/// PawParazzi/Button. Primary: Plum; Secondary: blanco con borde. 52 px (compacto 44 px).
/// "Loading conserva ancho y etiqueta. Disabled no invita a actuar."
class PawButton extends StatelessWidget {
  const PawButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PawButtonVariant.primary,
    this.loading = false,
    this.compact = false,
    this.expand = true,
  });

  const PawButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
    this.expand = true,
  }) : variant = PawButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final PawButtonVariant variant;
  final bool loading;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !loading;
    final primary = variant == PawButtonVariant.primary;
    final background = disabled && primary
        ? PawColors.surfaceTone3
        : primary
            ? PawColors.plum
            : PawColors.white;
    final foreground = disabled && primary
        ? PawColors.textMuted
        : primary
            ? PawColors.white
            : PawColors.plum;
    final radius = BorderRadius.circular(PawRadius.r16);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          const _Spinner(),
          const SizedBox(width: PawSpacing.s8),
        ],
        Flexible(
          child: Text(label,
              style: PawText.button.copyWith(color: foreground), overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      child: SizedBox(
        height: compact ? PawSizes.buttonCompact : PawSizes.button,
        width: expand ? double.infinity : null,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: primary ? BorderSide.none : const BorderSide(color: PawColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: PawSpacing.s20),
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Movimiento reducido: icono estático.
    if (MediaQuery.of(context).disableAnimations) {
      return const PawIcon(PawIcons.loader, size: 18);
    }
    return RotationTransition(turns: _controller, child: const PawIcon(PawIcons.loader, size: 18));
  }
}
