import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/paw_avatar.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../../feed/presentation/feed_controller.dart';
import '../data/comments_repository.dart';

/// Comentarios de una publicación (pantalla completa). El campo de texto queda fijo abajo y
/// sube con el teclado, sin tapar el botón de enviar.
class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _comments = <Comment>[];
  String? _cursor;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String? _loadError;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final page = await ref.read(commentsRepositoryProvider).list(widget.postId);
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(commentsRepositoryProvider).list(widget.postId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _comments.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } on ApiException catch (e) {
      if (mounted) showPawToast(context, title: e.message, success: false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final comment = await ref.read(commentsRepositoryProvider).add(widget.postId, text);
      if (!mounted) return;
      _input.clear();
      // Si quedan páginas por cargar, el comentario nuevo llegará con ellas (va al final).
      setState(() {
        if (!_hasMore) _comments.add(comment);
      });
      ref.read(feedControllerProvider.notifier).adjustCommentCount(widget.postId, 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients && !_hasMore) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _sendError = e.fieldErrors['body'] ?? e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Comment comment) async {
    final confirmed = await showPawConfirm(
      context,
      title: '¿Borrar este comentario?',
      body: '«${comment.body}» dejará de verse para todo el mundo.',
      confirmLabel: 'Borrar comentario',
      cancelLabel: 'Conservarlo',
    );
    if (!confirmed) return;
    try {
      await ref.read(commentsRepositoryProvider).delete(comment.id);
      if (!mounted) return;
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
      ref.read(feedControllerProvider.notifier).adjustCommentCount(widget.postId, -1);
    } on ApiException catch (e) {
      if (mounted) showPawToast(context, title: e.message, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: PawSpacing.screen),
              child: PawDetailHeader(title: 'Comentarios'),
            ),
            Expanded(child: _list()),
            Container(
              decoration: const BoxDecoration(
                color: PawColors.white,
                border: Border(top: BorderSide(color: PawColors.borderSubtle)),
              ),
              padding: const EdgeInsets.fromLTRB(PawSpacing.screen, PawSpacing.s12, PawSpacing.screen, PawSpacing.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: PawTextField(
                      label: 'Tu comentario',
                      hint: 'Di algo bonito',
                      controller: _input,
                      maxLength: 500,
                      maxLines: 4,
                      enabled: !_sending,
                      textCapitalization: TextCapitalization.sentences,
                      errorText: _sendError,
                    ),
                  ),
                  const SizedBox(width: PawSpacing.s12),
                  Padding(
                    padding: EdgeInsets.only(bottom: _sendError != null ? 29 : 4),
                    child: PawButton(label: 'Enviar', compact: true, expand: false, loading: _sending, onPressed: _send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(PawSpacing.screen),
        child: PawErrorState(title: 'No pudimos cargar los comentarios', message: _loadError!, onRetry: _load),
      );
    }
    if (_comments.isEmpty) {
      return const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: PawSpacing.screen),
        child: PawEmptyState(
          icon: PawIcons.messageCircle,
          title: 'Aún no hay comentarios',
          body: 'Sé la primera persona en decir algo sobre este momento.',
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(PawSpacing.screen, 0, PawSpacing.screen, PawSpacing.s16),
      itemCount: _comments.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: PawSpacing.s16),
      itemBuilder: (context, i) {
        if (i == _comments.length) {
          return PawButton.secondary(
            label: _loadingMore ? 'Cargando…' : 'Ver más comentarios',
            onPressed: _loadingMore ? null : _loadMore,
          );
        }
        return _CommentTile(comment: _comments[i], onDelete: () => _delete(_comments[i]));
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onDelete});

  final Comment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(name: comment.author.name, imageUrl: comment.author.avatarUrl, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: comment.author.name, style: PawText.body15Semi),
                TextSpan(text: '  ${relativeTime(comment.createdAt)}', style: PawText.caption12),
              ])),
              const SizedBox(height: 2),
              Text(comment.body, style: PawText.body14),
            ],
          ),
        ),
        if (comment.canDelete)
          PawIconButton(asset: PawIcons.ellipsis, semanticLabel: 'Borrar comentario', onPressed: onDelete),
      ],
    );
  }
}
