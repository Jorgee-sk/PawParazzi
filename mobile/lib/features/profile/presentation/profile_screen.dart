import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/media_cache.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_avatar.dart';
import '../../../core/widgets/paw_button.dart';
import '../../../core/widgets/paw_header.dart';
import '../../../core/widgets/paw_states.dart';
import '../../gamification/data/streak.dart';
import '../../gamification/presentation/paw_streak_card.dart';
import '../../pets/data/pet_repository.dart';
import '../../pets/presentation/pet_selector_tile.dart';

/// Perfil: identidad, PawStreak, mascotas y amistades.
/// Logros, PawPoints y recuerdos llegan en la fase 2 y todavía no se muestran.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final pets = ref.watch(myPetsProvider);
    final streak = ref.watch(streakProvider);
    if (me == null) return const SizedBox.shrink();
    final name = me.displayName ?? me.username ?? me.email;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: PawColors.plum,
        onRefresh: () async {
          ref.invalidate(myPetsProvider);
          ref.invalidate(streakProvider);
          await ref.read(sessionProvider.notifier).refreshMe();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: PawSpacing.screen),
          children: [
            const PawBrandHeader(title: 'Perfil'),
            Row(children: [
              UserAvatar(name: name, imageUrl: me.avatarUrl, size: 64),
              const SizedBox(width: PawSpacing.s16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: PawText.heading22),
                  if (me.username != null) Text('@${me.username}', style: PawText.caption13),
                ]),
              ),
            ]),
            const SizedBox(height: PawSpacing.s16),
            PawButton.secondary(label: 'Editar perfil', compact: true, onPressed: () => context.push(Routes.editProfile)),
            const SizedBox(height: PawSpacing.s24),
            switch (streak) {
              AsyncData(:final value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PawStreakCard(streak: value),
                  const SizedBox(height: PawSpacing.s8),
                  Text(
                    [
                      value.totalDays == 1 ? '1 día participado' : '${value.totalDays} días participados',
                      if (value.nextMilestone != null) 'próximo hito: ${value.nextMilestone} días',
                    ].join(' · '),
                    style: PawText.caption12,
                  ),
                ]),
              AsyncError(:final error) =>
                PawErrorState(message: ApiException.from(error).message, onRetry: () => ref.invalidate(streakProvider)),
              _ => const SizedBox(height: 66),
            },
            const SizedBox(height: PawSpacing.s32),
            Row(children: [
              const Expanded(child: Text('Mis mascotas', style: PawText.heading22)),
              PawButton(
                label: 'Añadir',
                compact: true,
                expand: false,
                onPressed: () => context.push(Routes.newPet),
              ),
            ]),
            const SizedBox(height: PawSpacing.s16),
            switch (pets) {
              AsyncData(:final value) => Column(children: [
                  for (final pet in value) ...[
                    PetSelectorTile(
                      pet: pet,
                      subtitle: [pet.species.label, if (pet.tags.isNotEmpty) pet.tags.take(2).join(', ')].join(' · '),
                      onTap: () => context.push(Routes.pet(pet.id)),
                    ),
                    const SizedBox(height: PawSpacing.s8),
                  ],
                ]),
              AsyncError(:final error) =>
                PawErrorState(message: ApiException.from(error).message, onRetry: () => ref.invalidate(myPetsProvider)),
              _ => const SizedBox(height: 64, child: Center(child: CircularProgressIndicator())),
            },
            const SizedBox(height: PawSpacing.s32),
            const Text('Amistades', style: PawText.heading22),
            const SizedBox(height: PawSpacing.s16),
            PawButton.secondary(label: 'Amigos y solicitudes', onPressed: () => context.push(Routes.friends)),
            const SizedBox(height: PawSpacing.s32),
            PawButton.secondary(
              label: 'Cerrar sesión',
              onPressed: () async {
                final ok = await showPawConfirm(
                  context,
                  title: '¿Cerrar sesión?',
                  body: 'Tus fotos, mascotas y racha se quedan guardadas. Cerrar sesión no elimina tu cuenta.',
                  confirmLabel: 'Cerrar sesión',
                );
                if (ok) {
                  ref.read(mediaCacheProvider).clear();
                  await ref.read(sessionProvider.notifier).logout();
                }
              },
            ),
            const SizedBox(height: PawSpacing.s16),
            Center(
              child: TextButton(
                onPressed: () => context.push(Routes.deleteAccount),
                child: Text('Eliminar cuenta', style: PawText.caption13Semi.copyWith(color: PawColors.error)),
              ),
            ),
            const SizedBox(height: PawSpacing.s32),
          ],
        ),
      ),
    );
  }
}
