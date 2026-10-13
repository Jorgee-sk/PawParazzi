import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';

class PawParazziApp extends ConsumerWidget {
  const PawParazziApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PawParazzi',
      debugShowCheckedModeBanner: false,
      theme: buildPawTheme(),
      routerConfig: ref.watch(routerProvider),
      // El diseño es móvil (390 px de referencia): en pantallas anchas se centra con un ancho máximo
      // en lugar de estirar fotos y botones.
      builder: (context, child) => ColoredBox(
        color: PawColors.cream,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
