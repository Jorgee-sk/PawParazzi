import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_icon.dart';
import '../../../core/widgets/paw_message.dart';
import '../../../core/widgets/paw_states.dart';
import '../../../core/widgets/paw_tag.dart';
import '../../../core/widgets/paw_text_field.dart';
import '../../feed/presentation/feed_controller.dart';
import '../../friends/data/friends_repository.dart';
import '../data/safety_repository.dart';

/// Abre el formulario de reporte. Devuelve true si se envió.
Future<bool> showReportSheet(BuildContext context, {required ReportTarget target, required String targetId}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: PawColors.cream,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(target: target, targetId: targetId),
  );
  if (sent == true && context.mounted) {
    showPawToast(context, title: 'Reporte enviado', body: 'Gracias. Lo revisaremos.');
  }
  return sent == true;
}

/// Pide confirmación y bloquea. Devuelve true si se bloqueó.
Future<bool> confirmAndBlock(BuildContext context, WidgetRef ref, {required String userId, required String name}) async {
  final confirmed = await showPawConfirm(
    context,
    title: '¿Bloquear a $name?',
    body: 'Dejaréis de ser amigos y de ver los momentos del otro, y no podrá enviarte solicitudes. '
        'No le avisaremos. Puedes desbloquear desde Amistades.',
    confirmLabel: 'Bloquear a $name',
  );
  if (!confirmed) return false;
  try {
    await ref.read(safetyRepositoryProvider).block(userId);
    ref.invalidate(feedControllerProvider);
    ref.invalidate(friendsOverviewProvider);
    ref.invalidate(blockedUsersProvider);
    if (context.mounted) showPawToast(context, title: 'Has bloqueado a $name');
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showPawToast(context, title: e.message, success: false);
    return false;
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.target, required this.targetId});

  final ReportTarget target;
  final String targetId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(safetyRepositoryProvider).report(
            target: widget.target,
            targetId: widget.targetId,
            reason: _reason!,
            details: _details.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.target == ReportTarget.post
        ? ReportReason.values
        : ReportReason.values.where((r) => r != ReportReason.notAPet).toList();
    return SafeArea(
      child: Padding(
        // El formulario sube con el teclado.
        padding: EdgeInsets.fromLTRB(
            PawSpacing.screen, 0, PawSpacing.screen, PawSpacing.s16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reportar ${widget.target.noun}', style: PawText.heading24),
              const SizedBox(height: PawSpacing.s8),
              const Text('La otra persona no sabrá que has sido tú.', style: PawText.caption13),
              const SizedBox(height: PawSpacing.s16),
              const Text('¿Qué ocurre?', style: PawText.caption13Semi),
              const SizedBox(height: PawSpacing.s8),
              Wrap(
                spacing: PawSpacing.s8,
                runSpacing: PawSpacing.s8,
                children: [
                  for (final reason in reasons)
                    PawChoiceTag(
                      label: reason.label,
                      selected: _reason == reason,
                      onChanged: (_) => setState(() => _reason = reason),
                    ),
                ],
              ),
              const SizedBox(height: PawSpacing.s16),
              PawTextField(
                label: 'Detalles (opcional)',
                hint: 'Cuéntanos lo que quieras añadir',
                controller: _details,
                maxLength: 500,
                maxLines: 3,
                enabled: !_sending,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_error != null) ...[
                const SizedBox(height: PawSpacing.s16),
                PawMessage(icon: PawIcons.info, title: _error!),
              ],
              const SizedBox(height: PawSpacing.s16),
              PawButton(
                label: _sending ? 'Enviando…' : 'Enviar reporte',
                loading: _sending,
                onPressed: _reason == null ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
