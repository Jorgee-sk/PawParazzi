import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/authed_image.dart';
import '../../../core/widgets/paw_action_sheet.dart';
import '../../../core/widgets/paw_avatar.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_tag.dart';
import '../../moments/data/post_models.dart';

/// PawParazzi/Post: autoría, foto (radio 24, 240 px) con tipo de publicación, cariños y texto.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onToggleReaction,
    this.onOpenPet,
    this.onOpenComments,
    this.menuActions = const [],
  });

  final Post post;
  final VoidCallback onToggleReaction;
  final ValueChanged<String>? onOpenPet;
  final VoidCallback? onOpenComments;

  /// Opciones del menú "…" (eliminar si es propia; reportar y bloquear si es ajena).
  final List<PawSheetAction> menuActions;

  String get _identity {
    final petNames = post.pets.map((p) => p.name).toList();
    if (petNames.isEmpty) return post.author.name;
    final pets = petNames.length == 1
        ? petNames.first
        : '${petNames.sublist(0, petNames.length - 1).join(', ')} y ${petNames.last}';
    return '${post.isMine ? 'Tú' : post.author.name} y $pets';
  }

  String get _meta {
    final parts = [relativeTime(post.createdAt), 'Amigos'];
    if (post.type == PostType.pawMoment && post.onTime != null) {
      parts.add(post.onTime! ? 'a tiempo' : 'fuera de la ventana');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final firstPet = post.pets.isEmpty ? null : post.pets.first;
    return Semantics(
      container: true,
      label: '${post.type.label} de $_identity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: post.author.name, imageUrl: post.author.avatarUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_identity, style: PawText.body15Semi, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(_meta, style: PawText.caption12),
                  ],
                ),
              ),
              if (firstPet != null) ...[
                const SizedBox(width: 10),
                Semantics(
                  button: onOpenPet != null,
                  label: 'Ver perfil de ${firstPet.name}',
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onOpenPet == null ? null : () => onOpenPet!(firstPet.id),
                    child: SizedBox.square(
                      dimension: PawSizes.touchTarget,
                      child: Center(child: PetAvatar(name: firstPet.name, imageUrl: firstPet.photoUrl, size: 30)),
                    ),
                  ),
                ),
              ],
              if (menuActions.isNotEmpty) ...[
                const SizedBox(width: 10),
                PawIconButton(
                  asset: PawIcons.ellipsis,
                  semanticLabel: 'Opciones de la publicación',
                  background: PawColors.white,
                  onPressed: () => showPawActionSheet(context, menuActions),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(PawRadius.r24),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (post.image != null)
                    AuthedImage(post.image!.url, semanticLabel: 'Foto: $_identity')
                  else
                    const ColoredBox(color: PawColors.surfaceTone2),
                  Positioned(
                    left: PawSpacing.s12,
                    top: PawSpacing.s12,
                    child: PawTag(post.type.label, background: PawColors.cream),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ReactionButton(reactions: post.reactions, onTap: onToggleReaction),
              const SizedBox(width: PawSpacing.s8),
              _CommentsButton(count: post.commentCount, onTap: onOpenComments),
            ],
          ),
          if (post.caption != null) ...[
            const SizedBox(height: 10),
            Text(post.caption!, style: PawText.body14),
          ],
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: PawSpacing.s8,
              runSpacing: PawSpacing.s8,
              children: [for (final t in post.tags) PawTag(t.label)],
            ),
          ],
        ],
      ),
    );
  }

}

class _CommentsButton extends StatelessWidget {
  const _CommentsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 comentario' : '$count comentarios';
    return Semantics(
      button: onTap != null,
      label: '$label. Toca para verlos',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(PawRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PawSpacing.s8),
          child: SizedBox(
            height: PawSizes.touchTarget,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PawIcon(PawIcons.messageCircle),
                const SizedBox(width: PawSpacing.s8),
                Text(label, style: PawText.meta13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.reactions, required this.onTap});

  final ReactionSummary reactions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = reactions.count;
    final label = count == 1 ? '1 cariño' : '$count cariños';
    return Semantics(
      button: true,
      toggled: reactions.reactedByMe,
      label: reactions.reactedByMe ? '$label. Has enviado un cariño. Toca para retirarlo' : '$label. Toca para enviar un cariño',
      excludeSemantics: true,
      child: Material(
        // Estado "enviado": píldora lavanda (como la pestaña activa) además del texto.
        color: reactions.reactedByMe ? PawColors.lavender : Colors.transparent,
        borderRadius: BorderRadius.circular(PawRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(PawRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PawSpacing.s8),
            child: SizedBox(
              height: PawSizes.touchTarget,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PawIcon(PawIcons.heart),
                  const SizedBox(width: PawSpacing.s8),
                  Text(reactions.reactedByMe ? '$label · incluido el tuyo' : label, style: PawText.meta13),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
