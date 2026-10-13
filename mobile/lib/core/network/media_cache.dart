import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'providers.dart';

/// Las imágenes son privadas (solo propietaria y amistades), así que se descargan a través del
/// cliente autenticado (que renueva la sesión si hace falta) y se guardan en una caché LRU en memoria.
class MediaCache {
  MediaCache(this._api, {this.maxEntries = 120});

  final ApiClient _api;
  final int maxEntries;
  final _cache = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List>>{};

  Uint8List? peek(String path) {
    final bytes = _cache.remove(path);
    if (bytes != null) _cache[path] = bytes; // marca como usada recientemente
    return bytes;
  }

  Future<Uint8List> load(String path) {
    final cached = peek(path);
    if (cached != null) return Future.value(cached);
    return _inFlight[path] ??= _api.getBytes(path).then((data) {
      final bytes = Uint8List.fromList(data);
      _cache[path] = bytes;
      while (_cache.length > maxEntries) {
        _cache.remove(_cache.keys.first);
      }
      return bytes;
    }).whenComplete(() {
      // Con cuerpo de bloque a propósito: `() => _inFlight.remove(path)` devolvería el propio Future
      // y whenComplete esperaría a que terminase... él mismo, dejando la imagen cargando para siempre.
      _inFlight.remove(path);
    });
  }

  void evict(String path) => _cache.remove(path);

  void clear() => _cache.clear();
}

final mediaCacheProvider = Provider<MediaCache>((ref) => MediaCache(ref.watch(apiClientProvider)));
