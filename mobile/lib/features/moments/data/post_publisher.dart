import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../media/data/media_repository.dart';
import 'post_models.dart';
import 'post_repository.dart';

/// Un intento de publicación. Conserva el `clientRequestId` y la imagen ya subida entre
/// reintentos: si la red falla después de que el servidor guardase la publicación, el reintento
/// devuelve la misma publicación (sin duplicados ni racha contada dos veces).
class PostPublisher {
  PostPublisher(this._media, this._posts, {String? clientRequestId})
      : clientRequestId = clientRequestId ?? const Uuid().v4();

  final MediaRepository _media;
  final PostRepository _posts;
  final String clientRequestId;
  String? _mediaId;

  bool get imageUploaded => _mediaId != null;

  Future<CreatePostResult> publish({
    required Uint8List bytes,
    required PostType type,
    required List<String> petIds,
    String? caption,
    List<PostTag> tags = const [],
  }) async {
    _mediaId ??= (await _media.upload(bytes, MediaPurpose.post)).id;
    return _posts.create(
      type: type,
      mediaId: _mediaId!,
      petIds: petIds,
      caption: caption,
      tags: tags,
      clientRequestId: clientRequestId,
    );
  }
}
