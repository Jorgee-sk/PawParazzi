import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_text_field.dart';
import 'brand_mark.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = const ApiException(code: 'local', message: 'Escribe tu email y tu contraseña.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(email: _email.text, password: _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final expired = session is SignedOut && session.expired;
    return _AuthScaffold(
      title: 'Caza lo inesperado.',
      subtitle: 'No busques la foto perfecta. Caza el momento más inesperado de tu mascota.',
      children: [
        if (expired && _error == null) ...[
          const PawMessage(
            icon: PawIcons.info,
            title: 'Tu sesión ha caducado',
            body: 'Vuelve a iniciar sesión para seguir.',
          ),
          const SizedBox(height: PawSpacing.s16),
        ],
        AutofillGroup(
          child: Column(children: [
            PawTextField(
              label: 'Email',
              hint: 'Tu email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: _error?.fieldErrors['email'],
            ),
            const SizedBox(height: PawSpacing.s16),
            PawTextField(
              label: 'Contraseña',
              hint: 'Tu contraseña',
              controller: _password,
              obscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              errorText: _error?.fieldErrors['password'],
            ),
          ]),
        ),
        if (_error != null && _error!.fieldErrors.isEmpty) ...[
          const SizedBox(height: PawSpacing.s16),
          PawMessage(icon: PawIcons.info, title: _error!.message),
        ],
        const SizedBox(height: PawSpacing.s24),
        PawButton(label: _loading ? 'Entrando…' : 'Entrar', loading: _loading, onPressed: _submit),
        const SizedBox(height: PawSpacing.s16),
        PawButton.secondary(label: 'Crear cuenta', onPressed: _loading ? null : () => context.go(Routes.register)),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  ApiException? _error;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    final email = _email.text.trim();
    setState(() {
      _emailError = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Ese email no parece válido.';
      _passwordError = _password.text.length >= 8 ? null : 'Necesita al menos 8 caracteres.';
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).register(email: _email.text, password: _password.text);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _emailError = e.fieldErrors['email'] ?? (e.code == 'email_taken' ? e.message : null);
          _passwordError = e.fieldErrors['password'];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showGeneralError = _error != null && _emailError == null && _passwordError == null;
    return _AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Después elegirás tu nombre de usuario y presentarás a tu primera mascota.',
      children: [
        AutofillGroup(
          child: Column(children: [
            PawTextField(
              label: 'Email',
              hint: 'Tu email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: _emailError,
            ),
            const SizedBox(height: PawSpacing.s16),
            PawTextField(
              label: 'Contraseña',
              hint: 'Mínimo 8 caracteres',
              controller: _password,
              obscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
              errorText: _passwordError,
            ),
          ]),
        ),
        if (showGeneralError) ...[
          const SizedBox(height: PawSpacing.s16),
          PawMessage(icon: PawIcons.info, title: _error!.message),
        ],
        const SizedBox(height: PawSpacing.s24),
        PawButton(label: _loading ? 'Creando cuenta…' : 'Crear cuenta', loading: _loading, onPressed: _submit),
        const SizedBox(height: PawSpacing.s16),
        PawButton.secondary(label: 'Ya tengo cuenta', onPressed: _loading ? null : () => context.go(Routes.login)),
      ],
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(PawSpacing.screen),
              children: [
                const SizedBox(height: PawSpacing.s16),
                const BrandMark(),
                const SizedBox(height: PawSpacing.s32),
                Text(title, style: PawText.display28),
                const SizedBox(height: PawSpacing.s12),
                Text(subtitle, style: PawText.title17),
                const SizedBox(height: PawSpacing.s32),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
