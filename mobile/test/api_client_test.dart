import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawparazzi/core/auth/token_storage.dart';
import 'package:pawparazzi/core/network/api_client.dart';
import 'package:pawparazzi/core/network/api_exception.dart';

/// Adaptador HTTP falso: responde según una función.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

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

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  test('ante un 401 renueva la sesión una vez y reintenta con el token nuevo', () async {
    final storage = MemoryTokenStorage();
    await storage.write(const AuthTokens(accessToken: 'viejo', refreshToken: 'r1'));

    final api = _FakeAdapter((o) => o.headers['Authorization'] == 'Bearer nuevo'
        ? _json(200, {'ok': true})
        : _json(401, {'code': 'unauthorized', 'message': 'Inicia sesión'}));
    final refresh = _FakeAdapter((o) => _json(200, {'accessToken': 'nuevo', 'refreshToken': 'r2'}));
    final client = ApiClient(
      baseUrl: 'http://test',
      storage: storage,
      dio: Dio()..httpClientAdapter = api,
      refreshDio: Dio()..httpClientAdapter = refresh,
    );

    // Dos peticiones simultáneas comparten una única renovación.
    final results = await Future.wait([
      client.get<Map<String, dynamic>>('/api/v1/users/me'),
      client.get<Map<String, dynamic>>('/api/v1/feed/friends'),
    ]);

    expect(results.every((r) => r['ok'] == true), isTrue);
    expect(refresh.requests, hasLength(1));
    expect((await storage.read())!.refreshToken, 'r2');
  });

  test('si la renovación es rechazada, avisa de sesión caducada y borra tokens', () async {
    final storage = MemoryTokenStorage();
    await storage.write(const AuthTokens(accessToken: 'viejo', refreshToken: 'r1'));
    var expired = false;
    final client = ApiClient(
      baseUrl: 'http://test',
      storage: storage,
      dio: Dio()..httpClientAdapter = _FakeAdapter((_) => _json(401, {'code': 'unauthorized', 'message': 'x'})),
      refreshDio: Dio()
        ..httpClientAdapter = _FakeAdapter((_) => _json(401, {'code': 'invalid_refresh_token', 'message': 'x'})),
    )..onSessionExpired = () => expired = true;

    await expectLater(
      client.get<Map<String, dynamic>>('/api/v1/users/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(expired, isTrue);
    expect(await storage.read(), isNull);
  });

  test('normaliza errores de validación con campos', () async {
    final client = ApiClient(
      baseUrl: 'http://test',
      storage: MemoryTokenStorage(),
      dio: Dio()
        ..httpClientAdapter = _FakeAdapter((_) => _json(400, {
              'code': 'validation_failed',
              'message': 'Revisa los campos marcados.',
              'fieldErrors': {'password': 'Necesita al menos 8 caracteres.'},
            })),
    );
    await expectLater(
      client.post<Map<String, dynamic>>('/api/v1/auth/register', data: {}, auth: false),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'validation_failed')
          .having((e) => e.fieldErrors['password'], 'password', 'Necesita al menos 8 caracteres.')),
    );
  });
}
