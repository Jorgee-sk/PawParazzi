import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../gamification/data/streak.dart';
import '../../gamification/presentation/paw_streak_card.dart';
import '../../moments/data/post_models.dart';
import '../../moments/data/post_repository.dart';
import '../../moments/presentation/paw_moment_card.dart';
import 'feed_controller.dart';
import 'post_card.dart';
import 'post_menu.dart';

/// Inicio: estado del PawMoment, PawStreak y feed de amigos. La foto es protagonista;
/// la gamificación acompaña.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refreshAll(WidgetRef ref) async {
    ref.invalidate(todayMomentProvider);
    ref.invalidate(streakProvider);
    await ref.read(feedControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    final today = ref.watch(todayMomentProvider);
    final streak = ref.watch(streakProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: PawColors.plum,
        onRefresh: () => _refreshAll(ref),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
              ref.read(feedControllerProvider.notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: PawSpacing.screen),
                sliver: SliverToBoxAdapter(child: PawBrandHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
                sliver: SliverList.list(children: [
                  switch (today) {
                    AsyncData(:final value) => PawMomentCard(
                        today: value,
                        onCapture: () => context.push(Routes.pawMoment),
                      ),
                    AsyncError() => PawMessage(
                        icon: PawIcons.zap,
                        title: 'No pudimos consultar el PawMoment de hoy',
                        body: 'Puedes publicarlo igualmente desde Capturar.',
                        trailing: TextButton(
                            onPressed: () => ref.invalidate(todayMomentProvider), child: const Text('Reintentar')),
                      ),
                    _ => const SizedBox(height: 120),
                  },
                  const SizedBox(height: PawSpacing.s16),
                  if (streak case AsyncData(:final value)) ...[
                    PawStreakCard(streak: value),
                    const SizedBox(height: PawSpacing.s24),
                  ],
                  const Text('Momentos de tus amigos', style: PawText.heading22),
                  const SizedBox(height: PawSpacing.s16),
                ]),
              ),
              ..._feedSlivers(context, ref, feed),
              const SliverToBoxAdapter(child: SizedBox(height: PawSpacing.s32)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(BuildContext context, WidgetRef ref, AsyncValue<FeedState> feed) {
    Widget padded(Widget sliver) =>
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen), sliver: sliver);

    return switch (feed) {
      AsyncData(:final value) when value.items.isEmpty => [
          padded(SliverToBoxAdapter(
            child: PawEmptyState(
              icon: PawIcons.users,
              title: 'Todavía no hay momentos',
              body: 'Invita a tus amigos o publica tu primera foto. No llenamos los vacíos con fotos demo.',
              actionLabel: 'Añadir amigos',
              onAction: () => context.push(Routes.friends),
            ),
          )),
        ],
      AsyncData(:final value) => [
          padded(SliverList.separated(
            itemCount: value.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: PawSpacing.s32),
            itemBuilder: (context, i) => _postCard(context, ref, value.items[i]),
          )),
          padded(SliverToBoxAdapter(child: _footer(ref, value))),
        ],
      AsyncError(:final error) => [
          padded(SliverToBoxAdapter(
            child: PawErrorState(
              title: 'No pudimos cargar el feed',
              message: ApiException.from(error).message,
              onRetry: () => ref.read(feedControllerProvider.notifier).refresh(),
            ),
          )),
        ],
      _ => [
          padded(SliverList.separated(
            itemCount: 2,
            separatorBuilder: (_, _) => const SizedBox(height: PawSpacing.s32),
            itemBuilder: (_, _) => const PostSkeleton(),
          )),
        ],
    };
  }

  Widget _postCard(BuildContext context, WidgetRef ref, Post post) {
    return PostCard(
      post: post,
      onOpenPet: (petId) => context.push(Routes.pet(petId)),
      onOpenComments: () => context.push(Routes.comments(post.id)),
      onToggleReaction: () async {
        final error = await ref.read(feedControllerProvider.notifier).toggleReaction(post);
        if (error != null && context.mounted) showPawToast(context, title: error, success: false);
      },
      menuActions: postMenuActions(context, ref, post, onDelete: () => _delete(context, ref, post)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Post post) async {
    final confirmed = await showPawConfirm(
      context,
      title: '¿Eliminar esta publicación?',
      body: 'Se borrarán la foto y el texto para ti y tus amigos. Si era tu PawMoment, el día sigue contando en tu racha.',
      confirmLabel: 'Eliminar publicación',
      cancelLabel: 'Conservarla',
    );
    if (!confirmed) return;
    try {
      await ref.read(postRepositoryProvider).delete(post.id);
      ref.read(feedControllerProvider.notifier).removePost(post.id);
      ref.invalidate(todayMomentProvider);
      if (context.mounted) showPawToast(context, title: 'Publicación eliminada');
    } on ApiException catch (e) {
      if (context.mounted) showPawToast(context, title: e.message, success: false);
    }
  }

  Widget _footer(WidgetRef ref, FeedState state) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.only(top: PawSpacing.s32),
        child: PostSkeleton(),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: PawSpacing.s24),
        child: PawErrorState(
          title: 'No pudimos cargar más momentos',
          message: state.loadMoreError!,
          onRetry: () => ref.read(feedControllerProvider.notifier).loadMore(),
        ),
      );
    }
    if (!state.hasMore) {
      return const Padding(
        padding: EdgeInsets.only(top: PawSpacing.s32),
        child: Text('Estás al día.', style: PawText.caption13, textAlign: TextAlign.center),
      );
    }
    return const SizedBox.shrink();
  }
}
