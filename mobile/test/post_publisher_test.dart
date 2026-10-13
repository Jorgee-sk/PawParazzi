import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pawparazzi/core/network/api_exception.dart';
import 'package:pawparazzi/features/media/data/media_repository.dart';
import 'package:pawparazzi/features/moments/data/post_models.dart';
import 'package:pawparazzi/features/moments/data/post_publisher.dart';
import 'package:pawparazzi/features/moments/data/post_repository.dart';
import 'package:pawparazzi/features/profile/data/user_models.dart';

class _MockMedia extends Mock implements MediaRepository {}

class _MockPosts extends Mock implements PostRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(MediaPurpose.post);
    registerFallbackValue(PostType.free);
    registerFallbackValue(Uint8List(0));
  });

  final post = Post(
    id: 'p1',
    type: PostType.pawMoment,
    createdAt: DateTime(2026, 10, 12),
    author: const UserSummary(id: 'u1', displayName: 'Elena'),
    pets: const [],
    tags: const [],
    reactions: const ReactionSummary(count: 0, reactedByMe: false),
    isMine: true,
  );

  test('un reintento reutiliza la imagen subida y el mismo clientRequestId', () async {
    final media = _MockMedia();
    final posts = _MockPosts();
    when(() => media.upload(any(), any())).thenAnswer((_) async => const UploadedMedia(id: 'm1', url: '/m1'));
    var calls = 0;
    when(() => posts.create(
          type: any(named: 'type'),
          mediaId: any(named: 'mediaId'),
          petIds: any(named: 'petIds'),
          clientRequestId: any(named: 'clientRequestId'),
          caption: any(named: 'caption'),
          tags: any(named: 'tags'),
        )).thenAnswer((_) async {
      if (calls++ == 0) throw const ApiException(code: 'network', message: 'sin red');
      return CreatePostResult(post: post, streakCounted: true, replayed: false);
    });

    final publisher = PostPublisher(media, posts, clientRequestId: 'req-1');
    final bytes = Uint8List.fromList([1, 2, 3]);

    await expectLater(
      publisher.publish(bytes: bytes, type: PostType.pawMoment, petIds: ['pet1']),
      throwsA(isA<ApiException>()),
    );
    expect(publisher.imageUploaded, isTrue);

    final result = await publisher.publish(bytes: bytes, type: PostType.pawMoment, petIds: ['pet1']);
    expect(result.streakCounted, isTrue);

    verify(() => media.upload(any(), MediaPurpose.post)).called(1);
    final ids = verify(() => posts.create(
          type: any(named: 'type'),
          mediaId: 'm1',
          petIds: any(named: 'petIds'),
          clientRequestId: captureAny(named: 'clientRequestId'),
          caption: any(named: 'caption'),
          tags: any(named: 'tags'),
        )).captured;
    expect(ids, ['req-1', 'req-1']);
  });
}
