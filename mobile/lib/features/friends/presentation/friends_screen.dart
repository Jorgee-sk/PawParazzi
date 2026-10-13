import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_action_sheet.dart';
import '../../../core/widgets/paw_avatar.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../profile/data/user_models.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';
import '../data/friends_repository.dart';

/// Solicitud de amistad → aceptación → publicaciones visibles en el feed.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _username = TextEditingController();
  bool _sending = false;
  String? _sendError;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(() => _sendError = 'Escribe un nombre de usuario.');
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final request = await ref.read(friendsRepositoryProvider).send(username);
      _username.clear();
      ref.invalidate(friendsOverviewProvider);
      if (request.accepted) ref.invalidate(feedControllerProvider);
      if (mounted) {
        showPawToast(context, title: request.accepted ? 'Ya sois amigos' : 'Solicitud enviada');
      }
    } on ApiException catch (e) {
      setState(() => _sendError = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _run(Future<void> Function() action, {String? success, bool refreshFeed = false}) async {
    try {
      await action();
      ref.invalidate(friendsOverviewProvider);
      if (refreshFeed) ref.invalidate(feedControllerProvider);
      if (success != null && mounted) showPawToast(context, title: success);
    } on ApiException catch (e) {
      if (mounted) showPawToast(context, title: e.message, success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(friendsOverviewProvider);
    final blocked = ref.watch(blockedUsersProvider);
    final repo = ref.read(friendsRepositoryProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: PawColors.plum,
          onRefresh: () async {
            ref.invalidate(friendsOverviewProvider);
            ref.invalidate(blockedUsersProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
            children: [
              const PawDetailHeader(title: 'Amistades'),
              if (me?.username != null)
                Text('Tu usuario es @${me!.username}. Compártelo para que te añadan.', style: PawText.caption13),
              const SizedBox(height: PawSpacing.s16),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: PawTextField(
                    label: 'Añadir por nombre de usuario',
                    hint: '@usuario',
                    controller: _username,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    errorText: _sendError,
                  ),
                ),
                const SizedBox(width: PawSpacing.s12),
                Padding(
                  padding: EdgeInsets.only(bottom: _sendError != null ? 25 : 0),
                  child: PawButton(label: 'Añadir', compact: true, expand: false, loading: _sending, onPressed: _send),
                ),
              ]),
              const SizedBox(height: PawSpacing.s32),
              switch (overview) {
                AsyncData(:final value) => _lists(value, repo),
                AsyncError(:final error) => PawErrorState(
                    message: ApiException.from(error).message,
                    onRetry: () => ref.invalidate(friendsOverviewProvider),
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
              const SizedBox(height: PawSpacing.s24),
              if (blocked case AsyncData(:final value) when value.isNotEmpty) ...[
                const Text('Personas bloqueadas', style: PawText.heading22),
                const SizedBox(height: PawSpacing.s16),
                for (final person in value) ...[
                  _PersonRow(
                    person: person,
                    subtitle: person.username != null ? '@${person.username}' : '',
                    actions: [
                      PawButton.secondary(
                        label: 'Desbloquear',
                        compact: true,
                        expand: false,
                        onPressed: () async {
                          try {
                            await ref.read(safetyRepositoryProvider).unblock(person.id);
                            ref.invalidate(blockedUsersProvider);
                            if (context.mounted) {
                              showPawToast(context,
                                  title: 'Has desbloqueado a ${person.name}',
                                  body: 'Para volver a ser amigos hay que enviar una solicitud.');
                            }
                          } on ApiException catch (e) {
                            if (context.mounted) showPawToast(context, title: e.message, success: false);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: PawSpacing.s12),
                ],
              ],
              const SizedBox(height: PawSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lists(FriendsOverview data, FriendsRepository repo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.incoming.isNotEmpty) ...[
          const Text('Solicitudes recibidas', style: PawText.heading22),
          const SizedBox(height: PawSpacing.s16),
          for (final r in data.incoming) ...[
            _PersonRow(
              person: r.requester,
              subtitle: 'Quiere ver tus momentos',
              actions: [
                PawButton(
                  label: 'Aceptar',
                  compact: true,
                  expand: false,
                  onPressed: () => _run(() => repo.accept(r.id), success: 'Ya sois amigos', refreshFeed: true),
                ),
                const SizedBox(width: PawSpacing.s8),
                PawButton.secondary(
                  label: 'Rechazar',
                  compact: true,
                  expand: false,
                  onPressed: () => _run(() => repo.reject(r.id)),
                ),
                PawIconButton(
                  asset: PawIcons.ellipsis,
                  semanticLabel: 'Más opciones para ${r.requester.name}',
                  onPressed: () => showPawActionSheet(context, [
                    PawSheetAction(
                      label: 'Bloquear a ${r.requester.name}',
                      subtitle: 'Se rechaza la solicitud y no podrá enviarte más.',
                      destructive: true,
                      onSelected: () =>
                          confirmAndBlock(context, ref, userId: r.requester.id, name: r.requester.name),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: PawSpacing.s12),
          ],
          const SizedBox(height: PawSpacing.s24),
        ],
        if (data.outgoing.isNotEmpty) ...[
          const Text('Solicitudes enviadas', style: PawText.heading22),
          const SizedBox(height: PawSpacing.s16),
          for (final r in data.outgoing) ...[
            _PersonRow(
              person: r.addressee,
              subtitle: 'Pendiente de respuesta',
              actions: [
                PawButton.secondary(
                  label: 'Cancelar',
                  compact: true,
                  expand: false,
                  onPressed: () => _run(() => repo.cancel(r.id)),
                ),
              ],
            ),
            const SizedBox(height: PawSpacing.s12),
          ],
          const SizedBox(height: PawSpacing.s24),
        ],
        const Text('Tus amigos', style: PawText.heading22),
        const SizedBox(height: PawSpacing.s16),
        if (data.friends.isEmpty)
          const PawEmptyState(
            icon: PawIcons.users,
            title: 'Todavía sin amigos',
            body: 'Cuando acepten tu solicitud, sus momentos aparecerán en tu Inicio.',
          ),
        for (final f in data.friends) ...[
          _PersonRow(
            person: f,
            subtitle: f.username != null ? '@${f.username}' : '',
            actions: [
              PawIconButton(
                asset: PawIcons.ellipsis,
                semanticLabel: 'Opciones de ${f.name}',
                onPressed: () => showPawActionSheet(context, [
                  PawSheetAction(
                    label: 'Eliminar amistad',
                    subtitle: 'Podréis volver a enviaros una solicitud.',
                    destructive: true,
                    onSelected: () async {
                      final ok = await showPawConfirm(
                        context,
                        title: '¿Eliminar a ${f.name} de tus amigos?',
                        body: 'Dejaréis de ver los momentos del otro. Podréis volver a enviaros una solicitud.',
                        confirmLabel: 'Eliminar amistad',
                      );
                      if (ok) await _run(() => repo.remove(f.id), refreshFeed: true);
                    },
                  ),
                  PawSheetAction(
                    label: 'Reportar a ${f.name}',
                    onSelected: () => showReportSheet(context, target: ReportTarget.user, targetId: f.id),
                  ),
                  PawSheetAction(
                    label: 'Bloquear a ${f.name}',
                    subtitle: 'No podrá enviarte solicitudes.',
                    destructive: true,
                    onSelected: () => confirmAndBlock(context, ref, userId: f.id, name: f.name),
                  ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: PawSpacing.s12),
        ],
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.subtitle, required this.actions});

  final UserSummary person;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PawSpacing.s12),
      decoration: BoxDecoration(
        color: PawColors.white,
        borderRadius: BorderRadius.circular(PawRadius.r16),
        border: Border.all(color: PawColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            UserAvatar(name: person.name, imageUrl: person.avatarUrl, size: 40),
            const SizedBox(width: PawSpacing.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(person.name, style: PawText.body15Semi, overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty) Text(subtitle, style: PawText.caption12, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (actions.length == 1) actions.first,
          ]),
          // Con varias acciones van en su propia línea para no tapar el nombre en pantallas estrechas.
          if (actions.length > 1) ...[
            const SizedBox(height: PawSpacing.s8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ],
      ),
    );
  }
}
