import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthTokens> register({required String email, required String password, required String timeZone}) async {
    final json = await _api.post<Map<String, dynamic>>('/api/v1/auth/register',
        data: {'email': email.trim(), 'password': password, 'timeZone': timeZone}, auth: false);
    final tokens = AuthTokens.fromJson(json);
    await _api.saveTokens(tokens);
    return tokens;
  }

  Future<AuthTokens> login({required String email, required String password}) async {
    final json = await _api.post<Map<String, dynamic>>('/api/v1/auth/login',
        data: {'email': email.trim(), 'password': password}, auth: false);
    final tokens = AuthTokens.fromJson(json);
    await _api.saveTokens(tokens);
    return tokens;
  }

  /// Revoca el refresh token en el servidor (si hay red) y borra los tokens locales siempre.
  Future<void> logout() async {
    final tokens = await _api.currentTokens();
    try {
      if (tokens != null) {
        await _api.post<void>('/api/v1/auth/logout', data: {'refreshToken': tokens.refreshToken}, auth: false);
      }
    } catch (_) {
      // Sin red: la sesión local se cierra igualmente; el token caducará en el servidor.
    } finally {
      await _api.clearTokens();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
