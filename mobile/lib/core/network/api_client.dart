import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import 'api_exception.dart';

/// Cliente HTTP centralizado:
/// - Añade el Bearer token a cada petición protegida.
/// - Ante un 401 renueva la sesión una sola vez (single-flight) y reintenta la petición.
/// - Si la renovación falla, avisa con [onSessionExpired] para volver al login.
/// - Convierte cualquier error en [ApiException].
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this._storage,
    Dio? dio,
    Dio? refreshDio,
  })  : dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio() {
    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
    );
    this.dio.options = options;
    _refreshDio.options = options;
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final String baseUrl;
  final Dio dio;
  final Dio _refreshDio;
  final TokenStorage _storage;

  AuthTokens? _tokens;
  bool _loaded = false;
  Future<AuthTokens?>? _refreshing;

  /// Se invoca cuando no es posible renovar la sesión.
  void Function()? onSessionExpired;

  static const skipAuthKey = 'skipAuth';
  static const _retriedKey = 'retried';

  Future<AuthTokens?> currentTokens() async {
    if (!_loaded) {
      _tokens = await _storage.read();
      _loaded = true;
    }
    return _tokens;
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    _tokens = tokens;
    _loaded = true;
    await _storage.write(tokens);
  }

  Future<void> clearTokens() async {
    _tokens = null;
    _loaded = true;
    await _storage.clear();
  }

  String resolve(String path) => path.startsWith('http') ? path : '$baseUrl$path';

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await currentTokens();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final unauthorized = err.response?.statusCode == 401;
    if (!unauthorized || options.extra[skipAuthKey] == true || options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    final refreshed = await refreshSession();
    if (refreshed == null) {
      onSessionExpired?.call();
      handler.next(err);
      return;
    }
    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Renueva la sesión. Peticiones concurrentes comparten la misma renovación.
  Future<AuthTokens?> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<AuthTokens?> _doRefresh() async {
    final current = await currentTokens();
    if (current == null) return null;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': current.refreshToken},
      );
      final tokens = AuthTokens.fromJson(response.data!);
      await saveTokens(tokens);
      return tokens;
    } on DioException catch (e) {
      // Solo un rechazo explícito invalida la sesión; un fallo de red no borra los tokens.
      if (e.response?.statusCode == 401) {
        await clearTokens();
      }
      return null;
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _call(() => dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data, Map<String, dynamic>? query, bool auth = true}) =>
      _call(() => dio.post<T>(path, data: data, queryParameters: query, options: _opts(auth)));

  Future<T> put<T>(String path, {Object? data}) => _call(() => dio.put<T>(path, data: data));

  Future<T> patch<T>(String path, {Object? data}) => _call(() => dio.patch<T>(path, data: data));

  Future<T> delete<T>(String path, {Object? data}) => _call(() => dio.delete<T>(path, data: data));

  /// Descarga con un enlace firmado (relativo a la API o absoluto, hacia el almacenamiento).
  /// No envía el token de sesión: la firma del enlace es la autorización, y el almacenamiento
  /// rechazaría una petición con dos credenciales.
  Future<List<int>> getPublicBytes(String url) => _call(() => dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, extra: {skipAuthKey: true}),
      ));

  Options _opts(bool auth) => Options(extra: {skipAuthKey: !auth});

  Future<T> _call<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      return response.data as T;
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
