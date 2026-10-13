import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/media_cache.dart';
import '../theme/tokens.dart';
import 'paw_icon.dart';

/// Imagen privada servida por la API (requiere token). Mientras carga muestra una superficie
/// estable (sin destellos, como el skeleton de Figma); si falla, un estado discreto.
class AuthedImage extends ConsumerStatefulWidget {
  const AuthedImage(this.path, {super.key, this.fit = BoxFit.cover, this.semanticLabel});

  final String path;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  ConsumerState<AuthedImage> createState() => _AuthedImageState();
}

class _AuthedImageState extends ConsumerState<AuthedImage> {
  Future<Uint8List>? _future;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant AuthedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _start();
  }

  void _start() {
    final cache = ref.read(mediaCacheProvider);
    _bytes = cache.peek(widget.path);
    _future = _bytes == null ? cache.load(widget.path) : null;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) return _image(bytes);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _image(snapshot.data!);
        if (snapshot.hasError) {
          return Container(
            color: PawColors.surfaceTone2,
            alignment: Alignment.center,
            child: InkWell(
              onTap: () => setState(_start),
              child: const Padding(
                padding: EdgeInsets.all(PawSpacing.s12),
                child: PawIcon(PawIcons.cloudOff, size: 24, semanticLabel: 'No se pudo cargar la imagen. Toca para reintentar'),
              ),
            ),
          );
        }
        return const ColoredBox(color: PawColors.surfaceTone2);
      },
    );
  }

  Widget _image(Uint8List bytes) => Image.memory(
        bytes,
        fit: widget.fit,
        gaplessPlayback: true,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.semanticLabel == null,
        width: double.infinity,
        height: double.infinity,
      );
}
