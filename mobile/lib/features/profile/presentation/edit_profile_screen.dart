
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/media_cache.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_avatar.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../media/data/media_repository.dart';
import '../data/user_repository.dart';

/// Editar perfil: foto, nombre visible y nombre de usuario.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  Uint8List? _newAvatar;
  bool _saving = false;
  String? _nameError;
  String? _usernameError;
  String? _error;

  static final _usernamePattern = RegExp(r'^[a-z0-9](?:[a-z0-9._]{1,28})[a-z0-9]$');

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserProvider);
    _displayName.text = me?.displayName ?? '';
    _username.text = me?.username ?? '';
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 88);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _newAvatar = bytes);
    } catch (_) {
      if (mounted) showPawToast(context, title: 'No pudimos abrir la cámara o la galería', success: false);
    }
  }

  Future<void> _save() async {
    final me = ref.read(currentUserProvider);
    final name = _displayName.text.trim();
    final username = _username.text.trim().toLowerCase();
    setState(() {
      _nameError = name.isEmpty ? 'Escribe cómo quieres que te vean.' : null;
      _usernameError =
          _usernamePattern.hasMatch(username) ? null : '3–30 caracteres: minúsculas, números, punto o guion bajo.';
      _error = null;
    });
    if (_nameError != null || _usernameError != null) return;
    setState(() => _saving = true);
    try {
      String? avatarId;
      if (_newAvatar != null) {
        avatarId = (await ref.read(mediaRepositoryProvider).upload(_newAvatar!, MediaPurpose.userAvatar)).id;
      }
      final updated = await ref.read(userRepositoryProvider).update(
            displayName: name == me?.displayName ? null : name,
            username: username == me?.username ? null : username,
            avatarMediaId: avatarId,
          );
      ref.read(sessionProvider.notifier).setMe(updated);
      // El nombre y la foto aparecen en las publicaciones del feed.
      if (avatarId != null) ref.read(mediaCacheProvider).clear();
      ref.invalidate(feedControllerProvider);
      if (!mounted) return;
      showPawToast(context, title: 'Perfil actualizado');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'username_taken') {
          _usernameError = e.message;
        } else {
          _usernameError = e.fieldErrors['username'];
          _nameError = e.fieldErrors['displayName'];
          if (_usernameError == null && _nameError == null) _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final name = _displayName.text.trim().isEmpty ? (me?.displayName ?? me?.email ?? '?') : _displayName.text.trim();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
          children: [
            const PawDetailHeader(title: 'Editar perfil'),
            Row(
              children: [
                if (_newAvatar != null)
                  ClipOval(
                    child: Image.memory(_newAvatar!, width: 96, height: 96, fit: BoxFit.cover,
                        semanticLabel: 'Nueva foto de perfil'),
                  )
                else
                  UserAvatar(name: name, imageUrl: me?.avatarUrl, size: 96),
                const SizedBox(width: PawSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PawButton.secondary(
                          label: 'Hacer foto', compact: true, onPressed: _saving ? null : () => _pick(ImageSource.camera)),
                      const SizedBox(height: PawSpacing.s8),
                      PawButton.secondary(
                          label: 'Elegir de la galería',
                          compact: true,
                          onPressed: _saving ? null : () => _pick(ImageSource.gallery)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: PawSpacing.s8),
            const Text('Tu foto de perfil puede ser tuya: no hace falta que salga una mascota.', style: PawText.caption12),
            const SizedBox(height: PawSpacing.s24),
            PawTextField(
              label: 'Nombre visible',
              controller: _displayName,
              maxLength: 50,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              errorText: _nameError,
            ),
            const SizedBox(height: PawSpacing.s16),
            PawTextField(
              label: 'Nombre de usuario',
              controller: _username,
              maxLength: 30,
              enabled: !_saving,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toLowerCase())),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              errorText: _usernameError,
            ),
            const SizedBox(height: PawSpacing.s8),
            const Text('Si lo cambias, tus amigos tendrán que usar el nuevo para encontrarte.', style: PawText.caption12),
            if (me != null) ...[
              const SizedBox(height: PawSpacing.s16),
              Text('Email: ${me.email}', style: PawText.caption13),
            ],
            if (_error != null) ...[
              const SizedBox(height: PawSpacing.s16),
              PawMessage(icon: PawIcons.info, title: _error!),
            ],
            const SizedBox(height: PawSpacing.s24),
            PawButton(label: _saving ? 'Guardando…' : 'Guardar', loading: _saving, onPressed: _save),
            const SizedBox(height: PawSpacing.s32),
          ],
        ),
      ),
    );
  }
}
