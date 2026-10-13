import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../profile/data/user_models.dart';

class Comment {
  const Comment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.canDelete,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final UserSummary author;
  final bool canDelete;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
        canDelete: json['canDelete'] as bool? ?? false,
      );
}

class CommentPage {
  const CommentPage({required this.items, this.nextCursor});

  final List<Comment> items;
  final String? nextCursor;
}

class CommentsRepository {
  CommentsRepository(this._api);

  final ApiClient _api;

  /// Del más antiguo al más reciente, paginado por cursor.
  Future<CommentPage> list(String postId, {String? cursor, int limit = 30}) async {
    final json = await _api.get<Map<String, dynamic>>('/api/v1/posts/$postId/comments',
        query: {'limit': limit, 'cursor': ?cursor});
    return CommentPage(
      items: (json['items'] as List).map((c) => Comment.fromJson(c as Map<String, dynamic>)).toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }

  Future<Comment> add(String postId, String body) async => Comment.fromJson(
      await _api.post<Map<String, dynamic>>('/api/v1/posts/$postId/comments', data: {'body': body.trim()}));

  Future<void> delete(String commentId) => _api.delete<void>('/api/v1/comments/$commentId');
}

final commentsRepositoryProvider =
    Provider<CommentsRepository>((ref) => CommentsRepository(ref.watch(apiClientProvider)));
