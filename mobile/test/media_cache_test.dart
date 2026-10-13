import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawparazzi/core/auth/token_storage.dart';
import 'package:pawparazzi/core/network/api_client.dart';
import 'package:pawparazzi/core/network/media_cache.dart';

class _BytesAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromBytes([0xFF, 0xD8, 0xFF, calls], 200, headers: {
      Headers.contentTypeHeader: ['image/jpeg'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _BytesAdapter adapter;
  late MediaCache cache;

  setUp(() {
    adapter = _BytesAdapter();
    cache = MediaCache(
      ApiClient(baseUrl: 'http://test', storage: MemoryTokenStorage(), dio: Dio()..httpClientAdapter = adapter),
      maxEntries: 2,
    );
  });

  test('load descarga los bytes y termina (regresión: se quedaba esperando para siempre)', () async {
    final bytes = await cache.load('/api/v1/media/a').timeout(const Duration(seconds: 2));
    expect(bytes, [0xFF, 0xD8, 0xFF, 1]);
    expect(cache.peek('/api/v1/media/a'), isNotNull);
  });

  test('peticiones simultáneas de la misma imagen comparten una sola descarga', () async {
    final results = await Future.wait([cache.load('/m/a'), cache.load('/m/a')]).timeout(const Duration(seconds: 2));
    expect(results[0], results[1]);
    expect(adapter.calls, 1);
    await cache.load('/m/a');
    expect(adapter.calls, 1, reason: 'la segunda vez sale de la caché');
  });

  test('la caché expulsa la imagen menos usada al superar el máximo', () async {
    await cache.load('/m/a');
    await cache.load('/m/b');
    cache.peek('/m/a'); // a pasa a ser la más reciente
    await cache.load('/m/c');
    expect(cache.peek('/m/b'), isNull);
    expect(cache.peek('/m/a'), isNotNull);
    expect(cache.peek('/m/c'), isNotNull);
  });
}
