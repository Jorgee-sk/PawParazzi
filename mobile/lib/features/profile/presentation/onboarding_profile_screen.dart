import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_tag.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../data/user_repository.dart';

/// Onboarding 1/2: nombre visible y nombre de usuario (necesario para recibir solicitudes).
class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends ConsumerState<OnboardingProfileScreen> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  bool _loading = false;
  String? _nameError;
  String? _usernameError;
  String? _generalError;

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

  Future<void> _submit() async {
    final name = _displayName.text.trim();
    final username = _username.text.trim().toLowerCase();
    setState(() {
      _nameError = name.isEmpty ? 'Escribe cómo quieres que te vean.' : null;
      _usernameError = _usernamePattern.hasMatch(username)
          ? null
          : '3–30 caracteres: minúsculas, números, punto o guion bajo.';
      _generalError = null;
    });
    if (_nameError != null || _usernameError != null) return;
    setState(() => _loading = true);
    try {
      final me = await ref.read(userRepositoryProvider).update(displayName: name, username: username);
      ref.read(sessionProvider.notifier).setMe(me);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'username_taken') {
          _usernameError = e.message;
        } else {
          _usernameError = e.fieldErrors['username'];
          _nameError = e.fieldErrors['displayName'];
          if (_usernameError == null && _nameError == null) _generalError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PawSpacing.screen),
          children: [
            const Align(alignment: Alignment.centerLeft, child: PawTag('PASO 1 DE 2', background: PawColors.butter)),
            const SizedBox(height: PawSpacing.s20),
            const Text('Así te verán tus amigos', style: PawText.display28),
            const SizedBox(height: PawSpacing.s12),
            const Text('Tu nombre de usuario sirve para que te envíen solicitudes de amistad.', style: PawText.title17),
            const SizedBox(height: PawSpacing.s32),
            PawTextField(
              label: 'Nombre visible',
              hint: 'Elena Torres',
              controller: _displayName,
              maxLength: 50,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              errorText: _nameError,
            ),
            const SizedBox(height: PawSpacing.s16),
            PawTextField(
              label: 'Nombre de usuario',
              hint: 'elena.nube',
              controller: _username,
              maxLength: 30,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toLowerCase())),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              errorText: _usernameError,
            ),
            if (_generalError != null) ...[
              const SizedBox(height: PawSpacing.s16),
              PawMessage(icon: PawIcons.info, title: _generalError!),
            ],
            const SizedBox(height: PawSpacing.s24),
            PawButton(label: _loading ? 'Guardando…' : 'Continuar', loading: _loading, onPressed: _submit),
            const SizedBox(height: PawSpacing.s16),
            PawButton.secondary(
              label: 'Cerrar sesión',
              onPressed: _loading ? null : () => ref.read(sessionProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}
