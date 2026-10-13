import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../profile/data/user_models.dart';

enum ReportTarget {
  post('POST', 'publicación'),
  comment('COMMENT', 'comentario'),
  user('USER', 'persona');

  const ReportTarget(this.api, this.noun);

  final String api;
  final String noun;
}

enum ReportReason {
  notAPet('NOT_A_PET', 'No es una foto de una mascota'),
  violence('VIOLENCE', 'Violencia o maltrato'),
  sexualContent('SEXUAL_CONTENT', 'Contenido sexual'),
  harassment('HARASSMENT', 'Acoso o insultos'),
  spam('SPAM', 'Spam o publicidad'),
  other('OTHER', 'Otro motivo');

  const ReportReason(this.api, this.label);

  final String api;
  final String label;
}

class SafetyRepository {
  SafetyRepository(this._api);

  final ApiClient _api;

  /// Reportar dos veces lo mismo no crea duplicados en el servidor.
  Future<void> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) =>
      _api.post<dynamic>('/api/v1/reports', data: {
        'targetType': target.api,
        'targetId': targetId,
        'reason': reason.api,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      });

  Future<void> block(String userId) => _api.put<dynamic>('/api/v1/blocks/$userId');

  Future<void> unblock(String userId) => _api.delete<dynamic>('/api/v1/blocks/$userId');

  Future<List<UserSummary>> blocked() async {
    final list = await _api.get<List<dynamic>>('/api/v1/blocks');
    return list.map((b) => UserSummary.fromJson((b as Map<String, dynamic>)['user'] as Map<String, dynamic>)).toList();
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) => SafetyRepository(ref.watch(apiClientProvider)));

final blockedUsersProvider =
    FutureProvider.autoDispose<List<UserSummary>>((ref) => ref.watch(safetyRepositoryProvider).blocked());
