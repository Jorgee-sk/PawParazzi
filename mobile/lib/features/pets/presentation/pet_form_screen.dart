import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/media_cache.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/authed_image.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_tag.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../../media/data/media_repository.dart';
import '../data/pet_models.dart';
import '../data/pet_repository.dart';

enum PetFormMode { onboarding, create, edit }

class PetFormScreen extends ConsumerStatefulWidget {
  const PetFormScreen({super.key, required this.mode, this.petId});

  final PetFormMode mode;
  final String? petId;

  @override
  ConsumerState<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends ConsumerState<PetFormScreen> {
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _description = TextEditingController();
  final _tagInput = TextEditingController();
  Species? _species;
  final _tags = <String>[];
  Uint8List? _newPhoto;
  String? _existingPhotoUrl;
  String? _existingPhotoId;
  bool _loadingPet = false;
  bool _saving = false;
  String? _nameError;
  String? _speciesError;
  String? _error;

  bool get _isEdit => widget.mode == PetFormMode.edit;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadPet();
  }

  Future<void> _loadPet() async {
    setState(() => _loadingPet = true);
    try {
      final pet = await ref.read(petRepositoryProvider).get(widget.petId!);
      _name.text = pet.name;
      _breed.text = pet.breed ?? '';
      _description.text = pet.description ?? '';
      _species = pet.species;
      _tags.addAll(pet.tags);
      _existingPhotoUrl = pet.photoThumbnailUrl;
      _existingPhotoId = pet.photoMediaId;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loadingPet = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _description.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _newPhoto = bytes);
    } catch (_) {
      if (mounted) {
        showPawToast(context, title: 'No pudimos abrir la cámara o la galería', success: false);
      }
    }
  }

  void _addTag() {
    final tag = _tagInput.text.trim();
    if (tag.isEmpty || _tags.length >= 8 || _tags.contains(tag)) return;
    setState(() {
      _tags.add(tag.length > 30 ? tag.substring(0, 30) : tag);
      _tagInput.clear();
    });
  }

  Future<void> _save() async {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Ponle un nombre.' : null;
      _speciesError = _species == null ? 'Elige una especie.' : null;
      _error = null;
    });
    if (_nameError != null || _speciesError != null) return;
    setState(() => _saving = true);
    try {
      String? photoId = _existingPhotoId;
      if (_newPhoto != null) {
        photoId = (await ref.read(mediaRepositoryProvider).upload(_newPhoto!, MediaPurpose.petPhoto)).id;
      }
      final draft = PetDraft(
        name: _name.text.trim(),
        species: _species!,
        breed: _breed.text.trim(),
        description: _description.text.trim(),
        tags: List.of(_tags),
        photoMediaId: photoId,
      );
      final repo = ref.read(petRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.petId!, draft);
        ref.read(mediaCacheProvider).clear();
        ref.invalidate(petProvider(widget.petId!));
      } else {
        await repo.create(draft);
      }
      ref.invalidate(myPetsProvider);
      if (widget.mode == PetFormMode.onboarding) {
        // El router lleva a Inicio en cuanto el perfil indica que ya hay mascota.
        await ref.read(sessionProvider.notifier).refreshMe();
        return;
      }
      await ref.read(sessionProvider.notifier).refreshMe();
      if (!mounted) return;
      showPawToast(context, title: _isEdit ? 'Cambios guardados' : 'Mascota añadida');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _nameError = e.fieldErrors['name'];
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showPawConfirm(
      context,
      title: '¿Eliminar a ${_name.text.trim()}?',
      body: 'Se borrará su perfil. Las publicaciones donde aparece se conservan, pero ya no estará vinculada a ellas.',
      confirmLabel: 'Eliminar perfil de mascota',
      cancelLabel: 'Conservarlo',
    );
    if (!confirmed) return;
    try {
      await ref.read(petRepositoryProvider).delete(widget.petId!);
      ref.invalidate(myPetsProvider);
      await ref.read(sessionProvider.notifier).refreshMe();
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showPawToast(context, title: e.message, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = widget.mode == PetFormMode.onboarding;
    return Scaffold(
      body: SafeArea(
        child: _loadingPet
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
                children: [
                  if (onboarding) ...[
                    const SizedBox(height: PawSpacing.screen),
                    const Align(
                        alignment: Alignment.centerLeft, child: PawTag('PASO 2 DE 2', background: PawColors.butter)),
                    const SizedBox(height: PawSpacing.s20),
                    const Text('Presenta a tu primera mascota', style: PawText.display28),
                    const SizedBox(height: PawSpacing.s12),
                    const Text('Podrás añadir más mascotas después desde tu perfil.', style: PawText.title17),
                    const SizedBox(height: PawSpacing.s24),
                  ] else
                    PawDetailHeader(title: _isEdit ? 'Editar mascota' : 'Nueva mascota'),
                  _PhotoPicker(
                    newPhoto: _newPhoto,
                    existingUrl: _existingPhotoUrl,
                    onCamera: () => _pickPhoto(ImageSource.camera),
                    onGallery: () => _pickPhoto(ImageSource.gallery),
                  ),
                  const SizedBox(height: PawSpacing.s20),
                  PawTextField(
                    label: 'Nombre',
                    hint: 'Nube',
                    controller: _name,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    errorText: _nameError,
                  ),
                  const SizedBox(height: PawSpacing.s16),
                  const Text('Especie', style: PawText.caption13Semi),
                  const SizedBox(height: PawSpacing.s8),
                  Wrap(spacing: PawSpacing.s8, runSpacing: PawSpacing.s8, children: [
                    for (final s in Species.values)
                      PawChoiceTag(label: s.label, selected: _species == s, onChanged: (_) => setState(() => _species = s)),
                  ]),
                  if (_speciesError != null) ...[
                    const SizedBox(height: PawSpacing.s8),
                    Text(_speciesError!, style: PawText.caption12.copyWith(color: PawColors.error)),
                  ],
                  const SizedBox(height: PawSpacing.s16),
                  PawTextField(label: 'Raza (opcional)', hint: 'Europeo común', controller: _breed, maxLength: 60),
                  const SizedBox(height: PawSpacing.s16),
                  PawTextField(
                    label: 'Descripción (opcional)',
                    hint: 'Experta en cajas y siestas al sol.',
                    controller: _description,
                    maxLength: 300,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: PawSpacing.s16),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: PawTextField(
                        label: 'Etiquetas (opcional)',
                        hint: 'Curiosa',
                        controller: _tagInput,
                        maxLength: 30,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: PawSpacing.s12),
                    PawButton(label: 'Añadir', compact: true, expand: false, onPressed: _addTag),
                  ]),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: PawSpacing.s12),
                    Wrap(spacing: PawSpacing.s8, runSpacing: PawSpacing.s8, children: [
                      for (final tag in _tags)
                        PawChoiceTag(
                          label: '$tag  ✕',
                          selected: true,
                          onChanged: (_) => setState(() => _tags.remove(tag)),
                        ),
                    ]),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: PawSpacing.s16),
                    PawMessage(icon: PawIcons.info, title: _error!),
                  ],
                  const SizedBox(height: PawSpacing.s24),
                  PawButton(
                    label: _saving ? 'Guardando…' : (onboarding ? 'Entrar en PawParazzi' : 'Guardar'),
                    loading: _saving,
                    onPressed: _save,
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: PawSpacing.s16),
                    PawButton.secondary(label: 'Eliminar mascota', onPressed: _saving ? null : _delete),
                  ],
                  if (onboarding) ...[
                    const SizedBox(height: PawSpacing.s16),
                    PawButton.secondary(
                      label: 'Cerrar sesión',
                      onPressed: _saving ? null : () => ref.read(sessionProvider.notifier).logout(),
                    ),
                  ],
                  const SizedBox(height: PawSpacing.s32),
                ],
              ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.newPhoto, required this.existingUrl, required this.onCamera, required this.onGallery});

  final Uint8List? newPhoto;
  final String? existingUrl;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final Widget preview = newPhoto != null
        ? Image.memory(newPhoto!, fit: BoxFit.cover)
        : existingUrl != null
            ? AuthedImage(existingUrl!)
            : const Center(child: PawIcon(PawIcons.pawPrint22, size: 40));
    return Row(
      children: [
        Semantics(
          label: 'Foto de perfil de la mascota',
          image: true,
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: PawColors.lavender, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
        ),
        const SizedBox(width: PawSpacing.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PawButton.secondary(label: 'Hacer foto', compact: true, onPressed: onCamera),
              const SizedBox(height: PawSpacing.s8),
              PawButton.secondary(label: 'Elegir de la galería', compact: true, onPressed: onGallery),
            ],
          ),
        ),
      ],
    );
  }
}
