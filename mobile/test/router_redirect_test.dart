import 'package:flutter_test/flutter_test.dart';
import 'package:pawparazzi/core/auth/session_controller.dart';
import 'package:pawparazzi/core/router/app_router.dart';
import 'package:pawparazzi/core/router/routes.dart';
import 'package:pawparazzi/features/profile/data/user_models.dart';

Me _me({bool profile = true, int pets = 1}) => Me(
      id: 'u1',
      email: 'elena@example.com',
      username: profile ? 'elena.nube' : null,
      displayName: profile ? 'Elena' : null,
      timeZone: 'Europe/Madrid',
      profileCompleted: profile,
      petCount: pets,
    );

void main() {
  group('Flujo Registro → perfil → primera mascota → feed', () {
    test('mientras se comprueba la sesión se muestra el arranque', () {
      expect(redirectFor(const SessionLoading(), Routes.home), Routes.splash);
      expect(redirectFor(const SessionUnavailable('sin red'), Routes.profile), Routes.splash);
    });

    test('sin sesión solo se permiten login y registro', () {
      expect(redirectFor(const SignedOut(), Routes.home), Routes.login);
      expect(redirectFor(const SignedOut(), Routes.register), isNull);
      expect(redirectFor(const SignedOut(), Routes.login), isNull);
    });

    test('tras registrarse, primero el perfil', () {
      expect(redirectFor(SignedIn(_me(profile: false, pets: 0)), Routes.register), Routes.onboardingProfile);
      expect(redirectFor(SignedIn(_me(profile: false, pets: 0)), Routes.home), Routes.onboardingProfile);
    });

    test('con perfil pero sin mascotas, la primera mascota', () {
      expect(redirectFor(SignedIn(_me(pets: 0)), Routes.onboardingProfile), Routes.onboardingPet);
      expect(redirectFor(SignedIn(_me(pets: 0)), Routes.capture), Routes.onboardingPet);
    });

    test('con perfil y mascota, al feed; las rutas internas se respetan', () {
      expect(redirectFor(SignedIn(_me()), Routes.onboardingPet), Routes.home);
      expect(redirectFor(SignedIn(_me()), Routes.login), Routes.home);
      expect(redirectFor(SignedIn(_me()), Routes.splash), Routes.home);
      expect(redirectFor(SignedIn(_me()), Routes.friends), isNull);
      expect(redirectFor(SignedIn(_me()), Routes.pet('abc')), isNull);
    });
  });
}
