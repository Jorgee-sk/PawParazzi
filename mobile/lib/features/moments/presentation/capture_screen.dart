import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../data/post_models.dart';

class ComposeArgs {
  const ComposeArgs({required this.bytes, required this.type});

  final Uint8List bytes;
  final PostType type;
}

/// Captura: pestaña "Capturar" (Foto libre) o modal PawMoment (sin navegación inferior).
/// Abre la cámara del sistema mediante image_picker; el visor integrado está pendiente (ver ROADMAP).
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.type, this.embedded = false, this.picker});

  final PostType type;

  /// true dentro de la pestaña "Capturar"; false como modal a pantalla completa.
  final bool embedded;

  final ImagePicker? picker;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  bool _busy = false;
  bool _cameraFailed = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _cameraFailed = false);
      await context.push(Routes.compose, extra: ComposeArgs(bytes: bytes, type: widget.type));
    } catch (_) {
      if (mounted && source == ImageSource.camera) setState(() => _cameraFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMoment = widget.type == PostType.pawMoment;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.embedded)
            const PawBrandHeader(title: 'Capturar')
          else
            const PawDetailHeader(title: 'PawMoment'),
          Text(
            isMoment
                ? 'Fotografía lo que esté haciendo ahora mismo. La ventana es una invitación: publicar después también cuenta.'
                : 'Foto libre: cualquier momento, cuando quieras. No suma racha.',
            style: PawText.caption13,
          ),
          const SizedBox(height: PawSpacing.s16),
          if (_cameraFailed) ...[
            const PawMessage(
              icon: PawIcons.cameraOff,
              title: 'Necesitamos la cámara',
              body: 'No pudimos abrirla. Revisa el permiso de cámara en los ajustes del dispositivo o elige una foto de la galería.',
            ),
            const SizedBox(height: PawSpacing.s16),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: PawColors.camera, borderRadius: BorderRadius.circular(PawRadius.r24)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PawSpacing.s24),
                    child: Text(
                      'No busques la foto perfecta.',
                      style: PawText.body15Semi.copyWith(color: PawColors.cream),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: PawSpacing.s24),
                  _Shutter(busy: _busy, onTap: () => _pick(ImageSource.camera)),
                  const SizedBox(height: PawSpacing.s32),
                ],
              ),
            ),
          ),
          const SizedBox(height: PawSpacing.s16),
          PawButton.secondary(label: 'Elegir de la galería', onPressed: _busy ? null : () => _pick(ImageSource.gallery)),
          const SizedBox(height: PawSpacing.s16),
        ],
      ),
    );
    if (widget.embedded) return SafeArea(bottom: false, child: body);
    return Scaffold(body: SafeArea(child: body));
  }
}

/// PawParazzi/Capture: disparador de 88 px sobre el fondo de cámara.
class _Shutter extends StatelessWidget {
  const _Shutter({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hacer foto',
      enabled: !busy,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Opacity(opacity: busy ? 0.5 : 1, child: const PawIcon(PawIcons.shutter, size: 88)),
      ),
    );
  }
}
