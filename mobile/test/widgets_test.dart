import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pawparazzi/core/network/api_exception.dart';
import 'package:pawparazzi/core/theme/app_theme.dart';
import 'package:pawparazzi/core/utils/time_format.dart';
import 'package:pawparazzi/features/feed/presentation/feed_controller.dart';
import 'package:pawparazzi/features/feed/presentation/home_screen.dart';
import 'package:pawparazzi/features/feed/presentation/post_card.dart';
import 'package:pawparazzi/features/gamification/data/streak.dart';
import 'package:pawparazzi/features/gamification/presentation/paw_streak_card.dart';
import 'package:pawparazzi/features/moments/data/post_models.dart';
import 'package:pawparazzi/features/moments/data/post_repository.dart';
import 'package:pawparazzi/features/pets/data/pet_models.dart';
import 'package:pawparazzi/features/profile/data/user_models.dart';

Widget _wrap(Widget child, {List overrides = const []}) => ProviderScope(
      overrides: [...overrides],
      retry: (_, _) => null,
      child: MaterialApp(theme: buildPawTheme(), home: Scaffold(body: child)),
    );

class _FeedWith extends FeedController {
  _FeedWith(this._result);

  final Future<FeedState> Function() _result;

  @override
  Future<FeedState> build() => _result();
}

final _today = TodayMoment(
  windowStart: DateTime(2026, 10, 12, 17, 42),
  windowEnd: DateTime(2026, 10, 12, 18, 12),
  status: MomentWindowStatus.late,
  participated: false,
);

const _streak = Streak(current: 0, best: 0, totalDays: 0, participatedToday: false, nextMilestone: 3);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('PawStreakCard', () {
    testWidgets('racha activa', (tester) async {
      await tester.pumpWidget(_wrap(const PawStreakCard(
          streak: Streak(current: 4, best: 14, totalDays: 20, participatedToday: true, nextMilestone: 7))));
      expect(find.text('4 días compartiendo'), findsOneWidget);
      expect(find.text('Tu mejor racha: 14 días · sin prisa'), findsOneWidget);
    });

    testWidgets('racha interrumpida conserva la mejor racha', (tester) async {
      await tester.pumpWidget(_wrap(
          const PawStreakCard(streak: Streak(current: 0, best: 14, totalDays: 20, participatedToday: false))));
      expect(find.text('Cada momento cuenta'), findsOneWidget);
      expect(find.text('Tu mejor racha sigue contigo: 14 días.'), findsOneWidget);
    });
  });

  testWidgets('PostCard muestra autoría, tipo, cariños y texto', (tester) async {
    final post = Post(
      id: 'p1',
      type: PostType.free,
      caption: 'El botín del paseo. No piensa devolverlo.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
      author: const UserSummary(id: 'u2', displayName: 'Dani'),
      pets: const [PetSummary(id: 'pet', name: 'Milo', species: Species.dog)],
      tags: const [PostTag.juego],
      reactions: const ReactionSummary(count: 3, reactedByMe: false),
      commentCount: 2,
      isMine: false,
    );
    var toggled = false;
    var openedComments = false;
    await tester.pumpWidget(_wrap(SingleChildScrollView(
      child: PostCard(
        post: post,
        onToggleReaction: () => toggled = true,
        onOpenComments: () => openedComments = true,
      ),
    )));
    expect(find.text('Dani y Milo'), findsOneWidget);
    expect(find.text('Hace 18 min · Amigos'), findsOneWidget);
    expect(find.text('Foto libre'), findsOneWidget);
    expect(find.text('3 cariños'), findsOneWidget);
    expect(find.text('El botín del paseo. No piensa devolverlo.'), findsOneWidget);
    // Sin opciones de borrado en publicaciones ajenas.
    expect(find.bySemanticsLabel('Opciones de la publicación'), findsNothing);
    await tester.tap(find.text('3 cariños'));
    expect(toggled, isTrue);
    await tester.tap(find.text('2 comentarios'));
    expect(openedComments, isTrue);
  });

  group('Inicio', () {
    testWidgets('estado vacío honesto con acción para añadir amigos', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        feedControllerProvider.overrideWith(() => _FeedWith(() async => const FeedState(items: []))),
        todayMomentProvider.overrideWith((ref) async => _today),
        streakProvider.overrideWith((ref) async => _streak),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no hay momentos'), findsOneWidget);
      expect(find.text('Añadir amigos'), findsOneWidget);
      // La ventana pasada no bloquea: el botón para capturar sigue disponible.
      expect(find.text('La ventana pasó, pero aún cuenta'), findsOneWidget);
      expect(find.text('Capturar PawMoment'), findsOneWidget);
    });

    testWidgets('error del feed con reintento', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        feedControllerProvider.overrideWith(() => _FeedWith(
            () async => throw const ApiException(code: 'network', message: 'No hay conexión con PawParazzi.'))),
        todayMomentProvider.overrideWith((ref) async => _today),
        streakProvider.overrideWith((ref) async => _streak),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar el feed'), findsOneWidget);
      expect(find.text('No hay conexión con PawParazzi.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('mientras carga muestra skeletons, no contenido inventado', (tester) async {
      await tester.pumpWidget(_wrap(const HomeScreen(), overrides: [
        feedControllerProvider.overrideWith(() => _FeedWith(() => Future.delayed(const Duration(seconds: 5), () => const FeedState(items: [])))),
        todayMomentProvider.overrideWith((ref) async => _today),
        streakProvider.overrideWith((ref) async => _streak),
      ]));
      await tester.pump();
      expect(find.bySemanticsLabel('Cargando publicación'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });
  });

  test('relativeTime', () {
    final now = DateTime(2026, 10, 12, 18, 0);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now: now), 'Ahora mismo');
    expect(relativeTime(now.subtract(const Duration(minutes: 18)), now: now), 'Hace 18 min');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), 'Hace 3 h');
    expect(relativeTime(DateTime(2026, 10, 11, 9), now: now), 'Ayer');
  });
}
