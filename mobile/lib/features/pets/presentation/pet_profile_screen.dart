import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_avatar.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_tag.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../feed/presentation/post_card.dart';
import '../../feed/presentation/post_menu.dart';
import '../../moments/data/post_models.dart';
import '../../moments/data/post_repository.dart';
import '../data/pet_models.dart';
import '../data/pet_repository.dart';

/// Perfil de mascota (propia o de una amistad) con su archivo de fotos paginado.
class PetProfileScreen extends ConsumerStatefulWidget {
  const PetProfileScreen({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends ConsumerState<PetProfileScreen> {
  final _posts = <Post>[];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _postsError;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _postsError = null;
    });
    try {
      final page = await ref.read(postRepositoryProvider).petPosts(widget.petId, cursor: _cursor);
      setState(() {
        _posts.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } on ApiException catch (e) {
      setState(() => _postsError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePost(Post post) async {
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
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p.id == post.id));
      showPawToast(context, title: 'Publicación eliminada');
    } on ApiException catch (e) {
      if (mounted) showPawToast(context, title: e.message, success: false);
    }
  }

  Future<void> _toggle(Post post) async {
    final repo = ref.read(postRepositoryProvider);
    try {
      final result = post.reactions.reactedByMe ? await repo.unreact(post.id) : await repo.react(post.id);
      setState(() {
        final i = _posts.indexWhere((p) => p.id == post.id);
        if (i >= 0) _posts[i] = _posts[i].copyWith(reactions: result);
      });
    } on ApiException catch (e) {
      if (mounted) showPawToast(context, title: e.message, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petProvider(widget.petId));
    return Scaffold(
      body: SafeArea(
        child: switch (pet) {
          AsyncData(:final value) => _content(value),
          AsyncError(:final error) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
              child: Column(children: [
                const PawDetailHeader(title: 'Mascota'),
                PawErrorState(
                  message: ApiException.from(error).message,
                  onRetry: () => ref.invalidate(petProvider(widget.petId)),
                ),
              ]),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _content(Pet pet) {
    final details = [pet.species.label, if (pet.breed != null) pet.breed!].join(' · ');
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
      children: [
        PawDetailHeader(
          title: pet.name,
          trailing: pet.isMine
              ? PawButton.secondary(
                  label: 'Editar',
                  compact: true,
                  expand: false,
                  onPressed: () async {
                    await context.push(Routes.editPet(pet.id));
                    if (mounted) ref.invalidate(petProvider(pet.id));
                  },
                )
              : null,
        ),
        Row(children: [
          PetAvatar(name: pet.name, imageUrl: pet.photoThumbnailUrl, size: 64),
          const SizedBox(width: PawSpacing.s16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pet.name, style: PawText.heading22),
              Text(details, style: PawText.caption13),
            ]),
          ),
        ]),
        if (pet.description != null) ...[
          const SizedBox(height: PawSpacing.s16),
          Text(pet.description!, style: PawText.body15),
        ],
        if (pet.tags.isNotEmpty) ...[
          const SizedBox(height: PawSpacing.s16),
          Wrap(spacing: PawSpacing.s8, runSpacing: PawSpacing.s8, children: [for (final t in pet.tags) PawTag(t)]),
        ],
        const SizedBox(height: PawSpacing.s32),
        const Text('Momentos', style: PawText.heading22),
        const SizedBox(height: PawSpacing.s16),
        if (_posts.isEmpty && !_loading && _postsError == null)
          PawEmptyState(
            icon: PawIcons.camera,
            title: 'Aún sin momentos',
            body: pet.isMine
                ? 'Cuando publiques una foto con ${pet.name}, aparecerá aquí.'
                : 'Cuando haya fotos de ${pet.name}, aparecerán aquí.',
          ),
        for (final post in _posts) ...[
          PostCard(
            post: post,
            onToggleReaction: () => _toggle(post),
            onOpenComments: () => context.push(Routes.comments(post.id)),
            menuActions: postMenuActions(context, ref, post, onDelete: () => _deletePost(post)),
          ),
          const SizedBox(height: PawSpacing.s32),
        ],
        if (_loading) const PostSkeleton(),
        if (_postsError != null) PawErrorState(message: _postsError!, onRetry: _loadMore),
        if (_hasMore && !_loading && _posts.isNotEmpty && _postsError == null)
          PawButton.secondary(label: 'Ver más momentos', onPressed: _loadMore),
        const SizedBox(height: PawSpacing.s32),
      ],
    );
  }
}
