import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/paw_action_sheet.dart';
import '../../moments/data/post_models.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';

/// Opciones del menú "…" de una publicación: eliminar si es propia; reportar y bloquear si es ajena.
List<PawSheetAction> postMenuActions(
  BuildContext context,
  WidgetRef ref,
  Post post, {
  required VoidCallback onDelete,
}) {
  if (post.isMine) {
    return [
      PawSheetAction(
        label: 'Eliminar publicación',
        subtitle: 'Se borran la foto y el texto.',
        destructive: true,
        onSelected: onDelete,
      ),
    ];
  }
  return [
    PawSheetAction(
      label: 'Reportar publicación',
      subtitle: 'Si no es una mascota o no debería estar aquí.',
      onSelected: () => showReportSheet(context, target: ReportTarget.post, targetId: post.id),
    ),
    PawSheetAction(
      label: 'Bloquear a ${post.author.name}',
      subtitle: 'Dejaréis de ver los momentos del otro.',
      destructive: true,
      onSelected: () => confirmAndBlock(context, ref, userId: post.author.id, name: post.author.name),
    ),
  ];
}
