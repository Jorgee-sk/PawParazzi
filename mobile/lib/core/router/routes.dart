abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingPet = '/onboarding/pet';

  // Pestañas
  static const home = '/home';
  static const capture = '/capturar';
  static const pawHunt = '/paw-hunt';
  static const groups = '/grupos';
  static const profile = '/perfil';

  // Pantallas completas (sin navegación inferior)
  static const pawMoment = '/pawmoment';
  static const compose = '/publicar';
  static const friends = '/amigos';
  static const editProfile = '/perfil/editar';
  static const deleteAccount = '/perfil/eliminar-cuenta';
  static String comments(String postId) => '/publicaciones/$postId/comentarios';
  static const newPet = '/mascotas/nueva';
  static String pet(String id) => '/mascotas/$id';
  static String editPet(String id) => '/mascotas/$id/editar';
}
