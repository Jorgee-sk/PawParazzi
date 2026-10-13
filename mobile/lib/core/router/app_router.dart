import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screens.dart';
import '../../features/comments/presentation/comments_screen.dart';
import '../../features/feed/presentation/home_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/moments/data/post_models.dart';
import '../../features/moments/presentation/capture_screen.dart';
import '../../features/moments/presentation/compose_screen.dart';
import '../../features/pets/presentation/pet_form_screen.dart';
import '../../features/pets/presentation/pet_profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/onboarding_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/shell/presentation/coming_soon_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/shell/presentation/splash_screen.dart';
import '../auth/session_controller.dart';
import '../widgets/paw_icon.dart';
import 'routes.dart';

/// Decide a dónde debe ir la persona según su sesión. Función pura para poder testearla.
String? redirectFor(SessionState session, String location) {
  const publicRoutes = {Routes.login, Routes.register};
  switch (session) {
    case SessionLoading():
    case SessionUnavailable():
      return location == Routes.splash ? null : Routes.splash;
    case SignedOut():
      return publicRoutes.contains(location) ? null : Routes.login;
    case SignedIn(:final me):
      if (!me.profileCompleted) {
        return location == Routes.onboardingProfile ? null : Routes.onboardingProfile;
      }
      if (!me.hasPets) {
        return location == Routes.onboardingPet ? null : Routes.onboardingPet;
      }
      const entry = {Routes.splash, Routes.login, Routes.register, Routes.onboardingProfile, Routes.onboardingPet};
      return entry.contains(location) || location == '/' ? Routes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<SessionState>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => session.value = next);
  ref.onDispose(session.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (context, state) => redirectFor(session.value, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.onboardingProfile, builder: (_, _) => const OnboardingProfileScreen()),
      GoRoute(
        path: Routes.onboardingPet,
        builder: (_, _) => const PetFormScreen(mode: PetFormMode.onboarding),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.capture, builder: (_, _) => const CaptureScreen(type: PostType.free, embedded: true)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.pawHunt,
              builder: (_, _) => const ComingSoonScreen(
                title: 'Paw Hunt',
                icon: PawIcons.navHuntActive,
                body: 'La misión fotográfica semanal llegará en la próxima fase. Aún no se puede participar.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.groups,
              builder: (_, _) => const ComingSoonScreen(
                title: 'Grupos',
                icon: PawIcons.navGroupsActive,
                body: 'Los PawSquads (grupos privados con racha compartida) llegarán en la próxima fase.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: Routes.pawMoment, builder: (_, _) => const CaptureScreen(type: PostType.pawMoment)),
      GoRoute(
        path: Routes.compose,
        redirect: (_, state) => state.extra is ComposeArgs ? null : Routes.capture,
        builder: (_, state) => ComposeScreen(args: state.extra! as ComposeArgs),
      ),
      GoRoute(path: Routes.friends, builder: (_, _) => const FriendsScreen()),
      GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
      GoRoute(
        path: '/publicaciones/:id/comentarios',
        builder: (_, state) => CommentsScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.newPet, builder: (_, _) => const PetFormScreen(mode: PetFormMode.create)),
      GoRoute(
        path: '/mascotas/:id',
        builder: (_, state) => PetProfileScreen(petId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'editar',
            builder: (_, state) => PetFormScreen(mode: PetFormMode.edit, petId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  );
});
