import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  // Sin reintentos automáticos de Riverpod: los estados de error se muestran y la persona decide reintentar.
  runApp(ProviderScope(retry: (_, _) => null, child: const PawParazziApp()));
}
