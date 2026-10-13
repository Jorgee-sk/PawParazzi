import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import 'post_models.dart';

class PostRepository {
  PostRepository(this._api);

  final ApiClient _api;

  /// `clientRequestId` se genera una vez por intento de publicación y se repite en los reintentos:
  /// el servidor devuelve la misma publicación sin duplicarla.
  Future<CreatePostResult> create({
    required PostType type,
    required String mediaId,
    required List<String> petIds,
    required String clientRequestId,
    String? caption,
    List<PostTag> tags = const [],
  }) async {
    final json = await _api.post<Map<String, dynamic>>('/api/v1/posts', data: {
      'type': type.api,
      'mediaId': mediaId,
      'petIds': petIds,
      if (caption != null && caption.trim().isNotEmpty) 'caption': caption.trim(),
      'tags': tags.map((t) => t.api).toList(),
      'clientRequestId': clientRequestId,
    });
    return CreatePostResult.fromJson(json);
  }

  Future<PostPage> friendsFeed({String? cursor, int limit = 10}) async {
    final json = await _api.get<Map<String, dynamic>>('/api/v1/feed/friends',
        query: {'limit': limit, 'cursor': ?cursor});
    return PostPage.fromJson(json);
  }

  Future<PostPage> petPosts(String petId, {String? cursor, int limit = 10}) async {
    final json = await _api.get<Map<String, dynamic>>('/api/v1/pets/$petId/posts',
        query: {'limit': limit, 'cursor': ?cursor});
    return PostPage.fromJson(json);
  }

  Future<void> delete(String postId) => _api.delete<void>('/api/v1/posts/$postId');

  Future<ReactionSummary> react(String postId) async =>
      ReactionSummary.fromJson(await _api.put<Map<String, dynamic>>('/api/v1/posts/$postId/reactions/me'));

  Future<ReactionSummary> unreact(String postId) async =>
      ReactionSummary.fromJson(await _api.delete<Map<String, dynamic>>('/api/v1/posts/$postId/reactions/me'));

  Future<TodayMoment> today() async =>
      TodayMoment.fromJson(await _api.get<Map<String, dynamic>>('/api/v1/moments/today'));
}

final postRepositoryProvider = Provider<PostRepository>((ref) => PostRepository(ref.watch(apiClientProvider)));

final todayMomentProvider = FutureProvider.autoDispose<TodayMoment>((ref) => ref.watch(postRepositoryProvider).today());
