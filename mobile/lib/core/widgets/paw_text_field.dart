import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'paw_icon.dart';

/// PawParazzi/Input: etiqueta siempre visible; focus 2 px Plum; error con borde y texto
/// (nunca solo con color). La contraseña permite mostrar/ocultar.
class PawTextField extends StatefulWidget {
  const PawTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.errorText,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.maxLength,
    this.maxLines = 1,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  State<PawTextField> createState() => _PawTextFieldState();
}

class _PawTextFieldState extends State<PawTextField> {
  late bool _hidden = widget.obscure;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(PawRadius.r16),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: PawText.caption13Semi),
        const SizedBox(height: PawSpacing.s8),
        TextField(
          controller: widget.controller,
          obscureText: _hidden,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          maxLength: widget.maxLength,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          minLines: 1,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          style: PawText.body15,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: PawText.body15.copyWith(color: PawColors.textMuted),
            filled: true,
            fillColor: PawColors.white,
            counterText: '',
            // 52 px de alto (Figma): 15 px de texto + 2 × 17 px de relleno vertical.
            contentPadding: const EdgeInsets.symmetric(horizontal: PawSpacing.s16, vertical: 17),
            enabledBorder: _border(hasError ? PawColors.error : PawColors.borderSubtle, 1),
            disabledBorder: _border(PawColors.borderSubtle, 1),
            focusedBorder: _border(hasError ? PawColors.error : PawColors.plum, 2),
            errorBorder: _border(PawColors.error, 1),
            focusedErrorBorder: _border(PawColors.error, 2),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Opacity(opacity: _hidden ? 1 : 0.55, child: const PawIcon(PawIcons.eyeOff, size: 20)),
                  )
                : null,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: PawSpacing.s8),
          Semantics(
            liveRegion: true,
            child: Text(widget.errorText!, style: PawText.caption12.copyWith(color: PawColors.error)),
          ),
        ],
      ],
    );
  }
}
