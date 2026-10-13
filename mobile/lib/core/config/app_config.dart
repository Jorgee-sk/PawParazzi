import 'package:flutter/foundation.dart';

/// Configuración en tiempo de compilación: `--dart-define=API_BASE_URL=https://api.ejemplo.com`.
abstract final class AppConfig {
  static const _fromEnv = String.fromEnvironment('API_BASE_URL');

  /// Por defecto apunta al backend local. En el emulador de Android "localhost" es el propio
  /// emulador, así que se usa 10.0.2.2 (la máquina anfitriona).
  static String get apiBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
