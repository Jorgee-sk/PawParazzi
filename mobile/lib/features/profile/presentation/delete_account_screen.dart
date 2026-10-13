import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/media_cache.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../data/user_repository.dart';

/// Eliminar la cuenta es distinto de cerrar sesión y tiene su propia confirmación:
/// explica qué se borra, pide la contraseña y vuelve a preguntar antes de hacerlo.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _deleting = false;
  String? _passwordError;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _passwordError = 'Escribe tu contraseña para confirmar.');
      return;
    }
    final confirmed = await showPawConfirm(
      context,
      title: '¿Eliminar tu cuenta para siempre?',
      body: 'Se borrarán tu perfil, tus mascotas, todas tus fotos, comentarios y tu racha. No se puede deshacer.',
      confirmLabel: 'Eliminar mi cuenta y mis datos',
      cancelLabel: 'Conservar mi cuenta',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _passwordError = null;
      _error = null;
    });
    try {
      await ref.read(userRepositoryProvider).deleteAccount(_password.text);
      ref.read(mediaCacheProvider).clear();
      // El router lleva al inicio de sesión en cuanto la sesión deja de existir.
      await ref.read(sessionProvider.notifier).accountDeleted();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'wrong_password') {
          _passwordError = e.message;
        } else {
          _error = e.message;
        }
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
          children: [
            const PawDetailHeader(title: 'Eliminar cuenta'),
            const Text('Esto borra tu cuenta y todos tus datos', style: PawText.heading24),
            const SizedBox(height: PawSpacing.s16),
            const Text(
              'Se eliminarán de forma definitiva:\n'
              '• Tu perfil y tu foto\n'
              '• Tus mascotas\n'
              '• Todas tus publicaciones y sus fotos\n'
              '• Tus comentarios y cariños\n'
              '• Tus amistades, solicitudes y bloqueos\n'
              '• Tu racha y tus días participados',
              style: PawText.body15,
            ),
            const SizedBox(height: PawSpacing.s16),
            const PawMessage(
              icon: PawIcons.info,
              title: 'No se puede deshacer',
              body: 'Si solo quieres salir de la app en este dispositivo, usa «Cerrar sesión» en tu perfil.',
            ),
            const SizedBox(height: PawSpacing.s24),
            PawTextField(
              label: 'Tu contraseña',
              hint: 'Confirma que eres tú',
              controller: _password,
              obscure: true,
              enabled: !_deleting,
              errorText: _passwordError,
              onSubmitted: (_) => _delete(),
            ),
            if (_error != null) ...[
              const SizedBox(height: PawSpacing.s16),
              PawMessage(icon: PawIcons.cloudOff, title: 'No se pudo eliminar la cuenta', body: _error),
            ],
            const SizedBox(height: PawSpacing.s24),
            PawButton(
              label: _deleting ? 'Eliminando…' : 'Eliminar mi cuenta',
              loading: _deleting,
              onPressed: _delete,
            ),
            const SizedBox(height: PawSpacing.s16),
            PawButton.secondary(
              label: 'Conservar mi cuenta',
              onPressed: _deleting ? null : () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: PawSpacing.s32),
          ],
        ),
      ),
    );
  }
}
