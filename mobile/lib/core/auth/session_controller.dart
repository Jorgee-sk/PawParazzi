import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/profile/data/user_models.dart';
import '../../features/profile/data/user_repository.dart';
import '../network/api_exception.dart';
import '../network/providers.dart';

sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

class SignedOut extends SessionState {
  const SignedOut({this.expired = false, this.accountDeleted = false});

  /// La sesión caducó (no la cerró la persona): se muestra un aviso en el login.
  final bool expired;

  /// La persona acaba de eliminar su cuenta: se confirma en el login.
  final bool accountDeleted;
}

/// No se pudo comprobar la sesión (p. ej. sin red al abrir la app). No borra los tokens.
class SessionUnavailable extends SessionState {
  const SessionUnavailable(this.message);

  final String message;
}

class SignedIn extends SessionState {
  const SignedIn(this.me);

  final Me me;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    ref.watch(apiClientProvider).onSessionExpired = _onExpired;
    Future.microtask(restore);
    return const SessionLoading();
  }

  Future<void> restore() async {
    state = const SessionLoading();
    final tokens = await ref.read(apiClientProvider).currentTokens();
    if (tokens == null) {
      state = const SignedOut();
      return;
    }
    await _loadMe();
  }

  Future<void> login({required String email, required String password}) async {
    await ref.read(authRepositoryProvider).login(email: email, password: password);
    await _loadMe(throwOnError: true);
  }

  Future<void> register({required String email, required String password}) async {
    await ref.read(authRepositoryProvider).register(email: email, password: password, timeZone: await _timeZone());
    await _loadMe(throwOnError: true);
  }

  /// Vuelve a leer el perfil (p. ej. tras crear la primera mascota).
  Future<void> refreshMe() => _loadMe(throwOnError: true);

  void setMe(Me me) => state = SignedIn(me);

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const SignedOut();
  }

  /// La cuenta ya no existe en el servidor: solo queda borrar los tokens locales.
  Future<void> accountDeleted() async {
    await ref.read(apiClientProvider).clearTokens();
    state = const SignedOut(accountDeleted: true);
  }

  Future<void> _loadMe({bool throwOnError = false}) async {
    try {
      final me = await ref.read(userRepositoryProvider).me();
      state = SignedIn(me);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ref.read(apiClientProvider).clearTokens();
        state = const SignedOut(expired: true);
      } else if (state is! SignedIn) {
        state = SessionUnavailable(e.message);
      }
      if (throwOnError) rethrow;
    }
  }

  void _onExpired() {
    if (state is SignedIn) state = const SignedOut(expired: true);
  }

  static Future<String> _timeZone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return 'UTC';
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Persona autenticada; solo debe usarse en pantallas protegidas por el router.
final currentUserProvider = Provider<Me?>((ref) {
  final session = ref.watch(sessionProvider);
  return session is SignedIn ? session.me : null;
});
