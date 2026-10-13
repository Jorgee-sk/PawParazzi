import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../moments/data/post_models.dart';
import '../../moments/data/post_repository.dart';

class FeedState {
  const FeedState({required this.items, this.nextCursor, this.loadingMore = false, this.loadMoreError});

  final List<Post> items;
  final String? nextCursor;
  final bool loadingMore;
  final String? loadMoreError;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({List<Post>? items, String? nextCursor, bool clearCursor = false, bool? loadingMore,
      String? loadMoreError, bool clearError = false}) {
    return FeedState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Feed de amigos paginado por cursor desde el backend (no se descarga todo el histórico).
class FeedController extends AsyncNotifier<FeedState> {
  static const pageSize = 10;

  @override
  Future<FeedState> build() async {
    final page = await ref.read(postRepositoryProvider).friendsFeed(limit: pageSize);
    return FeedState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref.read(postRepositoryProvider).friendsFeed(cursor: current.nextCursor, limit: pageSize);
      final known = current.items.map((p) => p.id).toSet();
      state = AsyncData(FeedState(
        items: [...current.items, ...page.items.where((p) => !known.contains(p.id))],
        nextCursor: page.nextCursor,
      ));
    } on ApiException catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false, loadMoreError: e.message));
    }
  }

  /// Cariño con actualización optimista; si falla se restaura el estado anterior.
  Future<String?> toggleReaction(Post post) async {
    final before = post.reactions;
    final optimistic = ReactionSummary(
      count: before.count + (before.reactedByMe ? -1 : 1),
      reactedByMe: !before.reactedByMe,
    );
    _replace(post.id, optimistic);
    try {
      final repo = ref.read(postRepositoryProvider);
      final result = before.reactedByMe ? await repo.unreact(post.id) : await repo.react(post.id);
      _replace(post.id, result);
      return null;
    } on ApiException catch (e) {
      _replace(post.id, before);
      return e.message;
    }
  }

  /// Mantiene el contador al día cuando se añade o borra un comentario desde su pantalla.
  void adjustCommentCount(String postId, int delta) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: [
        for (final p in current.items)
          p.id == postId ? p.copyWith(commentCount: (p.commentCount + delta).clamp(0, 1 << 31)) : p,
      ],
    ));
  }

  void removePost(String postId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: current.items.where((p) => p.id != postId).toList()));
  }

  void _replace(String postId, ReactionSummary reactions) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: [for (final p in current.items) p.id == postId ? p.copyWith(reactions: reactions) : p],
    ));
  }
}

final feedControllerProvider = AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);
