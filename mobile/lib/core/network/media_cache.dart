import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'api_exception.dart';
import 'providers.dart';

/// Descarga y guarda en memoria (LRU) las imágenes de la app.
///
/// La API devuelve para cada imagen un enlace firmado que caduca. Puede apuntar directamente al
/// almacenamiento (URL absoluta) o a la propia API (ruta relativa); en ambos casos se descarga
/// **sin** el token de sesión: la firma del enlace es la autorización.
///
/// La firma cambia en cada respuesta de la API, así que la caché se indexa por la ruta del enlace
/// (sin parámetros), que identifica la imagen de forma estable. Si el enlace ha caducado, se pide
/// uno nuevo al backend —que vuelve a comprobar el permiso— y se reintenta una vez.
class MediaCache {
  MediaCache(this._api, {this.maxEntries = 120});

  final ApiClient _api;
  final int maxEntries;
  final _cache = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List>>{};

  /// Identidad estable de la imagen: la ruta sin la firma ni la caducidad.
  static String cacheKey(String url) {
    final uri = Uri.parse(url);
    final variant = uri.queryParameters['variant'];
    return variant == null ? uri.path : '${uri.path}?variant=$variant';
  }

  Uint8List? peek(String url) {
    final key = cacheKey(url);
    final bytes = _cache.remove(key);
    if (bytes != null) _cache[key] = bytes; // marca como usada recientemente
    return bytes;
  }

  Future<Uint8List> load(String url) {
    final cached = peek(url);
    if (cached != null) return Future.value(cached);
    final key = cacheKey(url);
    return _inFlight[key] ??= _download(url).then((bytes) {
      _cache[key] = bytes;
      while (_cache.length > maxEntries) {
        _cache.remove(_cache.keys.first);
      }
      return bytes;
    }).whenComplete(() {
      // Con cuerpo de bloque a propósito: `() => _inFlight.remove(key)` devolvería el propio Future
      // y whenComplete esperaría a que terminase... él mismo, dejando la imagen cargando para siempre.
      _inFlight.remove(key);
    });
  }

  Future<Uint8List> _download(String url) async {
    try {
      return Uint8List.fromList(await _api.getPublicBytes(url));
    } on ApiException catch (e) {
      // 401/403: el enlace ha caducado (o el almacenamiento ya no lo acepta). Se renueva una vez.
      if (e.statusCode != 401 && e.statusCode != 403) rethrow;
      final fresh = await _api.post<Map<String, dynamic>>('/api/v1/media/links/refresh', data: {'url': url});
      return Uint8List.fromList(await _api.getPublicBytes(fresh['url'] as String));
    }
  }

  void evict(String url) => _cache.remove(cacheKey(url));

  void clear() => _cache.clear();
}

final mediaCacheProvider = Provider<MediaCache>((ref) => MediaCache(ref.watch(apiClientProvider)));
