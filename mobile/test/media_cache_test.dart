import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawparazzi/core/auth/token_storage.dart';
import 'package:pawparazzi/core/network/api_client.dart';
import 'package:pawparazzi/core/network/api_exception.dart';
import 'package:pawparazzi/core/network/media_cache.dart';

/// Adaptador HTTP falso que registra las peticiones y responde según una función.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _image(int marker) => ResponseBody.fromBytes([0xFF, 0xD8, 0xFF, marker], 200, headers: {
      Headers.contentTypeHeader: ['image/jpeg'],
    });

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

Future<(MediaCache, _Adapter)> _cache(ResponseBody Function(RequestOptions) handler, {int maxEntries = 120}) async {
  final adapter = _Adapter(handler);
  final storage = MemoryTokenStorage();
  await storage.write(const AuthTokens(accessToken: 'token-de-sesion', refreshToken: 'r'));
  final api = ApiClient(baseUrl: 'http://api.test', storage: storage, dio: Dio()..httpClientAdapter = adapter);
  return (MediaCache(api, maxEntries: maxEntries), adapter);
}

void main() {
  test('load descarga los bytes y termina (regresión: se quedaba esperando para siempre)', () async {
    final (cache, _) = await _cache((_) => _image(1));
    final bytes = await cache.load('/api/v1/media/a/content?variant=full&exp=1&sig=x').timeout(const Duration(seconds: 2));
    expect(bytes, [0xFF, 0xD8, 0xFF, 1]);
  });

  test('las imágenes se piden sin el token de sesión, también al almacenamiento', () async {
    final (cache, adapter) = await _cache((_) => _image(1));
    await cache.load('/api/v1/media/a/content?variant=thumb&exp=1&sig=x');
    await cache.load('http://almacen.test:8333/bucket/media/u/b.jpg?X-Amz-Signature=abc');

    expect(adapter.requests, hasLength(2));
    for (final request in adapter.requests) {
      expect(request.headers.containsKey('Authorization'), isFalse);
    }
    expect(adapter.requests[0].uri.host, 'api.test');
    expect(adapter.requests[1].uri.toString(), startsWith('http://almacen.test:8333/bucket/media/u/b.jpg'));
  });

  test('la caché ignora la firma: el mismo fichero con otro enlace no se vuelve a descargar', () async {
    final (cache, adapter) = await _cache((_) => _image(1));
    await cache.load('http://almacen.test/bucket/media/u/a.jpg?X-Amz-Signature=primera');
    await cache.load('http://almacen.test/bucket/media/u/a.jpg?X-Amz-Signature=segunda');
    expect(adapter.requests, hasLength(1));

    // En la API, la variante forma parte de la identidad: completa y miniatura son ficheros distintos.
    await cache.load('/api/v1/media/a/content?variant=full&exp=1&sig=x');
    await cache.load('/api/v1/media/a/content?variant=thumb&exp=2&sig=y');
    await cache.load('/api/v1/media/a/content?variant=thumb&exp=3&sig=z');
    expect(adapter.requests, hasLength(3));
  });

  test('si el enlace ha caducado pide uno nuevo con la sesión y reintenta una vez', () async {
    final (cache, adapter) = await _cache((o) {
      if (o.path.contains('links/refresh')) {
        return _json(200, {'url': '/api/v1/media/a/content?variant=full&exp=9&sig=nueva'});
      }
      return o.uri.queryParameters['sig'] == 'nueva'
          ? _image(7)
          : _json(403, {'code': 'link_expired', 'message': 'El enlace ha caducado o no es válido.'});
    });

    final bytes = await cache.load('/api/v1/media/a/content?variant=full&exp=1&sig=vieja');

    expect(bytes.last, 7);
    final refresh = adapter.requests.singleWhere((r) => r.path.contains('links/refresh'));
    expect(refresh.headers['Authorization'], 'Bearer token-de-sesion');
    expect((refresh.data as Map)['url'], contains('sig=vieja'));
    expect(adapter.requests, hasLength(3));
  });

  test('si ya no hay permiso para verla, la renovación falla y no se reintenta en bucle', () async {
    final (cache, adapter) = await _cache((o) => o.path.contains('links/refresh')
        ? _json(404, {'code': 'media_not_found', 'message': 'Imagen no encontrada.'})
        : _json(403, {'code': 'link_expired', 'message': 'caducado'}));

    await expectLater(
      cache.load('/api/v1/media/a/content?variant=full&exp=1&sig=vieja'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
    expect(adapter.requests, hasLength(2));
  });

  test('peticiones simultáneas de la misma imagen comparten una sola descarga', () async {
    final (cache, adapter) = await _cache((_) => _image(1));
    final results = await Future.wait([cache.load('/m/a?sig=1'), cache.load('/m/a?sig=2')]);
    expect(results[0], results[1]);
    expect(adapter.requests, hasLength(1));
  });

  test('la caché expulsa la imagen menos usada al superar el máximo', () async {
    final (cache, _) = await _cache((_) => _image(1), maxEntries: 2);
    await cache.load('/m/a');
    await cache.load('/m/b');
    cache.peek('/m/a'); // a pasa a ser la más reciente
    await cache.load('/m/c');
    expect(cache.peek('/m/b'), isNull);
    expect(cache.peek('/m/a'), isNotNull);
    expect(cache.peek('/m/c'), isNotNull);
  });
}
