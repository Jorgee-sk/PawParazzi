import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawparazzi/core/network/api_exception.dart';
import 'package:pawparazzi/core/theme/app_theme.dart';
import 'package:pawparazzi/features/feed/presentation/post_card.dart';
import 'package:pawparazzi/features/feed/presentation/post_menu.dart';
import 'package:pawparazzi/features/moments/data/post_models.dart';
import 'package:pawparazzi/features/pets/data/pet_models.dart';
import 'package:pawparazzi/features/profile/data/user_models.dart';
import 'package:pawparazzi/features/profile/data/user_repository.dart';
import 'package:pawparazzi/features/profile/presentation/delete_account_screen.dart';
import 'package:pawparazzi/features/safety/data/safety_repository.dart';

class _MockSafety extends Mock implements SafetyRepository {}

class _MockUsers extends Mock implements UserRepository {}

Post _post({required bool mine}) => Post(
      id: 'p1',
      type: PostType.free,
      createdAt: DateTime.now(),
      author: const UserSummary(id: 'u2', displayName: 'Dani'),
      pets: const [PetSummary(id: 'pet', name: 'Milo', species: Species.dog)],
      tags: const [],
      reactions: const ReactionSummary(count: 0, reactedByMe: false),
      isMine: mine,
    );

Widget _app(Widget home, {List overrides = const []}) => ProviderScope(
      overrides: [...overrides],
      retry: (_, _) => null,
      child: MaterialApp(theme: buildPawTheme(), home: home),
    );

Widget _card(Post post, {VoidCallback? onDelete}) => Scaffold(
      body: Consumer(
        builder: (context, ref, _) => SingleChildScrollView(
          child: PostCard(
            post: post,
            onToggleReaction: () {},
            menuActions: postMenuActions(context, ref, post, onDelete: onDelete ?? () {}),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() {
    initializeDateFormatting('es');
    registerFallbackValue(ReportTarget.post);
    registerFallbackValue(ReportReason.other);
  });

  testWidgets('en una publicación propia el menú solo ofrece eliminarla', (tester) async {
    var deleted = false;
    await tester.pumpWidget(_app(_card(_post(mine: true), onDelete: () => deleted = true)));
    await tester.tap(find.bySemanticsLabel('Opciones de la publicación'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar publicación'), findsOneWidget);
    expect(find.text('Reportar publicación'), findsNothing);
    await tester.tap(find.text('Eliminar publicación'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('en una publicación ajena se puede reportar: hay que elegir motivo antes de enviar', (tester) async {
    final safety = _MockSafety();
    when(() => safety.report(
          target: any(named: 'target'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
        )).thenAnswer((_) async {});
    await tester.pumpWidget(
        _app(_card(_post(mine: false)), overrides: [safetyRepositoryProvider.overrideWithValue(safety)]));

    await tester.tap(find.bySemanticsLabel('Opciones de la publicación'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar publicación'), findsNothing);
    expect(find.text('Bloquear a Dani'), findsOneWidget);
    await tester.tap(find.text('Reportar publicación'));
    await tester.pumpAndSettle();

    // Sin motivo, enviar no hace nada.
    await tester.tap(find.text('Enviar reporte'));
    await tester.pump();
    verifyNever(() => safety.report(
        target: any(named: 'target'),
        targetId: any(named: 'targetId'),
        reason: any(named: 'reason'),
        details: any(named: 'details')));

    await tester.tap(find.text('No es una foto de una mascota'));
    await tester.pump();
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();

    verify(() => safety.report(
        target: ReportTarget.post, targetId: 'p1', reason: ReportReason.notAPet, details: any(named: 'details'))).called(1);
    expect(find.text('Reporte enviado'), findsOneWidget);
  });

  testWidgets('bloquear pide confirmación nombrando a la persona', (tester) async {
    final safety = _MockSafety();
    when(() => safety.block(any())).thenAnswer((_) async {});
    await tester.pumpWidget(
        _app(_card(_post(mine: false)), overrides: [safetyRepositoryProvider.overrideWithValue(safety)]));

    await tester.tap(find.bySemanticsLabel('Opciones de la publicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquear a Dani'));
    await tester.pumpAndSettle();
    expect(find.text('¿Bloquear a Dani?'), findsOneWidget);
    verifyNever(() => safety.block(any()));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => safety.block(any()));
  });

  group('Eliminar cuenta', () {
    testWidgets('exige contraseña y una segunda confirmación antes de llamar al servidor', (tester) async {
      final users = _MockUsers();
      when(() => users.deleteAccount(any())).thenThrow(
          const ApiException(code: 'wrong_password', message: 'La contraseña no es correcta.', statusCode: 403));
      tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          _app(const DeleteAccountScreen(), overrides: [userRepositoryProvider.overrideWithValue(users)]));

      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu contraseña para confirmar.'), findsOneWidget);
      verifyNever(() => users.deleteAccount(any()));

      await tester.enterText(find.byType(TextField), 'mi-clave');
      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar tu cuenta para siempre?'), findsOneWidget);

      // Cancelar en el diálogo no borra nada.
      await tester.tap(find.text('Conservar mi cuenta').last);
      await tester.pumpAndSettle();
      verifyNever(() => users.deleteAccount(any()));

      await tester.tap(find.text('Eliminar mi cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar mi cuenta y mis datos'));
      await tester.pumpAndSettle();
      verify(() => users.deleteAccount('mi-clave')).called(1);
      expect(find.text('La contraseña no es correcta.'), findsOneWidget);
    });
  });
}
