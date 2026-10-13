import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';

enum MediaPurpose { post, petPhoto, userAvatar }

extension on MediaPurpose {
  String get api => switch (this) {
        MediaPurpose.post => 'POST',
        MediaPurpose.petPhoto => 'PET_PHOTO',
        MediaPurpose.userAvatar => 'USER_AVATAR',
      };
}

class UploadedMedia {
  const UploadedMedia({required this.id, required this.url});

  final String id;
  final String url;
}

class MediaRepository {
  MediaRepository(this._api);

  final ApiClient _api;

  /// Sube la imagen. El servidor valida el contenido real y elimina EXIF/GPS al re-codificarla.
  Future<UploadedMedia> upload(Uint8List bytes, MediaPurpose purpose) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: 'foto.jpg', contentType: DioMediaType('image', 'jpeg')),
    });
    final json = await _api.post<Map<String, dynamic>>('/api/v1/media', data: form, query: {'purpose': purpose.api});
    return UploadedMedia(id: json['id'] as String, url: json['url'] as String);
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) => MediaRepository(ref.watch(apiClientProvider)));
