import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_tag.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../gamification/data/streak.dart';
import '../../media/data/media_repository.dart';
import '../../pets/data/pet_repository.dart';
import '../../pets/presentation/pet_selector_tile.dart';
import '../data/post_models.dart';
import '../data/post_publisher.dart';
import '../data/post_repository.dart';
import 'capture_screen.dart';

/// Revisión y publicación (pantalla completa, sin navegación inferior).
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, required this.args});

  final ComposeArgs args;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late PostType _type = widget.args.type;
  final _selectedPets = <String>{};
  final _tags = <PostTag>{};
  final _caption = TextEditingController();
  late final PostPublisher _publisher =
      PostPublisher(ref.read(mediaRepositoryProvider), ref.read(postRepositoryProvider));

  bool _publishing = false;
  /// Permite salir sin confirmación (tras publicar o tras confirmar el descarte).
  bool _allowPop = false;
  ApiException? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final result = await _publisher.publish(
        bytes: widget.args.bytes,
        type: _type,
        petIds: _selectedPets.toList(),
        caption: _caption.text,
        tags: _tags.toList(),
      );
      _allowPop = true;
      ref.invalidate(feedControllerProvider);
      ref.invalidate(todayMomentProvider);
      ref.invalidate(streakProvider);
      if (!mounted) return;
      showPawToast(
        context,
        title: 'Foto publicada',
        body: result.streakCounted ? 'Tu momento ya está en el feed. +1 día de racha.' : 'Tu momento ya está en el feed.',
      );
      context.go(Routes.home);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// PopScope lee canPop del último build: se actualiza el estado y se sale en el siguiente frame.
  void _leave() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<bool> _confirmDiscard() => showPawConfirm(
        context,
        title: '¿Descartar este borrador?',
        body: 'La foto no se ha publicado. Si la descartas, se borrará solo de este borrador.',
        confirmLabel: 'Descartar borrador',
        cancelLabel: 'Seguir editando',
      );

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(myPetsProvider);
    final today = ref.watch(todayMomentProvider);
    final momentDone = today.value?.participated ?? false;
    final canPublish = _selectedPets.isNotEmpty && !_publishing;
    final rejected = _error?.code == 'image_rejected';

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _publishing) return;
        if (await _confirmDiscard()) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
            children: [
              const PawDetailHeader(title: 'Revisar y publicar'),
              ClipRRect(
                borderRadius: BorderRadius.circular(PawRadius.r24),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(widget.args.bytes, fit: BoxFit.cover, semanticLabel: 'Foto que vas a publicar'),
                ),
              ),
              const SizedBox(height: PawSpacing.s20),
              const Text('Tipo de publicación', style: PawText.caption13Semi),
              const SizedBox(height: PawSpacing.s8),
              Wrap(spacing: PawSpacing.s8, runSpacing: PawSpacing.s8, children: [
                PawChoiceTag(
                  label: PostType.pawMoment.label,
                  selected: _type == PostType.pawMoment,
                  onChanged: momentDone || _publishing ? (_) {} : (_) => setState(() => _type = PostType.pawMoment),
                ),
                PawChoiceTag(
                  label: PostType.free.label,
                  selected: _type == PostType.free,
                  onChanged: _publishing ? (_) {} : (_) => setState(() => _type = PostType.free),
                ),
              ]),
              const SizedBox(height: PawSpacing.s8),
              Text(_typeHint(today.value, momentDone), style: PawText.caption12),
              const SizedBox(height: PawSpacing.s20),
              const Text('¿Quién sale en la foto?', style: PawText.caption13Semi),
              const SizedBox(height: PawSpacing.s8),
              switch (pets) {
                AsyncData(:final value) => Column(
                    children: [
                      for (final pet in value) ...[
                        PetSelectorTile(
                          pet: pet,
                          subtitle: _selectedPets.contains(pet.id)
                              ? 'Protagonista de este momento'
                              : 'Puedes elegir varias mascotas',
                          selected: _selectedPets.contains(pet.id),
                          onTap: _publishing
                              ? null
                              : () => setState(() => _selectedPets.contains(pet.id)
                                  ? _selectedPets.remove(pet.id)
                                  : _selectedPets.add(pet.id)),
                        ),
                        const SizedBox(height: PawSpacing.s8),
                      ],
                    ],
                  ),
                AsyncError(:final error) => PawErrorState(
                    message: ApiException.from(error).message,
                    onRetry: () => ref.invalidate(myPetsProvider),
                  ),
                _ => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
              },
              const SizedBox(height: PawSpacing.s12),
              PawTextField(
                label: 'Texto (opcional)',
                controller: _caption,
                hint: 'El botín del paseo. No piensa devolverlo.',
                maxLength: 500,
                maxLines: 4,
                enabled: !_publishing,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: PawSpacing.s20),
              const Text('Etiquetas (opcional)', style: PawText.caption13Semi),
              const SizedBox(height: PawSpacing.s8),
              Wrap(
                spacing: PawSpacing.s8,
                runSpacing: PawSpacing.s8,
                children: [
                  for (final tag in PostTag.values)
                    PawChoiceTag(
                      label: tag.label,
                      selected: _tags.contains(tag),
                      onChanged: (v) => setState(() => v ? _tags.add(tag) : _tags.remove(tag)),
                    ),
                ],
              ),
              const SizedBox(height: PawSpacing.s24),
              if (_error != null) ...[
                _ErrorBlock(
                  error: _error!,
                  onPublishAsFree: _type == PostType.pawMoment
                      ? () {
                          setState(() => _type = PostType.free);
                          _publish();
                        }
                      : null,
                ),
                const SizedBox(height: PawSpacing.s16),
              ],
              PawButton(
                label: _publishing ? 'Publicando…' : (_error != null && !rejected ? 'Reintentar' : 'Publicar'),
                loading: _publishing,
                // Una foto rechazada no se puede reintentar: hay que elegir otra.
                onPressed: canPublish && !rejected ? _publish : null,
              ),
              if (_selectedPets.isEmpty && !_publishing)
                const Padding(
                  padding: EdgeInsets.only(top: PawSpacing.s8),
                  child: Text('Elige al menos una mascota para publicar.', style: PawText.caption12),
                ),
              const SizedBox(height: PawSpacing.s16),
              PawButton.secondary(
                label: 'Repetir foto',
                onPressed: _publishing
                    ? null
                    : () async {
                        if (await _confirmDiscard()) _leave();
                      },
              ),
              const SizedBox(height: PawSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }

  String _typeHint(TodayMoment? today, bool momentDone) {
    if (_type == PostType.free) {
      return momentDone
          ? 'Ya compartiste tu PawMoment de hoy. Las fotos libres no suman racha.'
          : 'Foto libre: cualquier momento, sin racha.';
    }
    if (today == null) return 'PawMoment: tu participación diaria.';
    return switch (today.status) {
      MomentWindowStatus.open => 'Dentro de la ventana (hasta las ${hourMinute(today.windowEnd)}): se marcará "a tiempo".',
      MomentWindowStatus.upcoming =>
        'La ventana abre a las ${hourMinute(today.windowStart)}. Publicar ahora también cuenta para tu racha.',
      MomentWindowStatus.late => 'Fuera de la ventana: también cuenta para tu racha.',
    };
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, this.onPublishAsFree});

  final ApiException error;
  final VoidCallback? onPublishAsFree;

  @override
  Widget build(BuildContext context) {
    if (error.code == 'already_participated') {
      return Column(children: [
        PawMessage(icon: PawIcons.info, title: 'Ya hay PawMoment hoy', body: error.message),
        if (onPublishAsFree != null) ...[
          const SizedBox(height: PawSpacing.s12),
          PawButton.secondary(label: 'Publicar como Foto libre', onPressed: onPublishAsFree),
        ],
      ]);
    }
    if (error.code == 'image_rejected') {
      return PawMessage(icon: PawIcons.info, title: 'No podemos publicar esta foto', body: error.message);
    }
    if (error.isNetwork || error.statusCode == null || error.statusCode! >= 500) {
      return const PawMessage(
        icon: PawIcons.cloudOff,
        title: 'Tu foto está a salvo',
        body: 'La subida no terminó. Conservamos foto, mascota y texto.',
      );
    }
    return PawMessage(icon: PawIcons.info, title: 'No se pudo publicar', body: error.message);
  }
}
