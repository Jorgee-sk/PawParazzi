import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import 'user_models.dart';

class UserRepository {
  UserRepository(this._api);

  final ApiClient _api;

  Future<Me> me() async => Me.fromJson(await _api.get<Map<String, dynamic>>('/api/v1/users/me'));

  Future<Me> update({String? username, String? displayName, String? timeZone, String? avatarMediaId}) async {
    final json = await _api.patch<Map<String, dynamic>>('/api/v1/users/me', data: {
      'username': ?username,
      'displayName': ?displayName,
      'timeZone': ?timeZone,
      'avatarMediaId': ?avatarMediaId,
    });
    return Me.fromJson(json);
  }

  /// Elimina la cuenta y todos sus datos. El servidor exige la contraseña como confirmación.
  Future<void> deleteAccount(String password) =>
      _api.delete<dynamic>('/api/v1/users/me', data: {'password': password});
}

final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository(ref.watch(apiClientProvider)));
