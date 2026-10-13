import '../../pets/data/pet_models.dart';
import '../../profile/data/user_models.dart';

enum PostType {
  pawMoment('PAW_MOMENT', 'PawMoment'),
  free('FREE', 'Foto libre');

  const PostType(this.api, this.label);

  final String api;
  final String label;

  static PostType fromApi(String v) => v == 'PAW_MOMENT' ? pawMoment : free;
}

/// Categorías manuales (orden de Figma: Descanso, Juego, Exterior, Travesuras, Interacciones, Adorables, Otras).
enum PostTag {
  descanso('DESCANSO', 'Descanso'),
  juego('JUEGO', 'Juego'),
  exterior('EXTERIOR', 'Exterior'),
  travesuras('TRAVESURAS', 'Travesuras'),
  interacciones('INTERACCIONES', 'Interacciones'),
  adorables('ADORABLES', 'Adorables'),
  otras('OTRAS', 'Otras');

  const PostTag(this.api, this.label);

  final String api;
  final String label;

  static PostTag? fromApi(String v) {
    for (final t in PostTag.values) {
      if (t.api == v) return t;
    }
    return null;
  }
}

class PostImage {
  const PostImage({required this.url, required this.thumbnailUrl, required this.width, required this.height});

  final String url;
  final String thumbnailUrl;
  final int width;
  final int height;

  factory PostImage.fromJson(Map<String, dynamic> json) => PostImage(
        url: json['url'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        width: (json['width'] as num).toInt(),
        height: (json['height'] as num).toInt(),
      );
}

class ReactionSummary {
  const ReactionSummary({required this.count, required this.reactedByMe});

  final int count;
  final bool reactedByMe;

  factory ReactionSummary.fromJson(Map<String, dynamic> json) =>
      ReactionSummary(count: (json['count'] as num).toInt(), reactedByMe: json['reactedByMe'] as bool);
}

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.author,
    required this.pets,
    required this.tags,
    required this.reactions,
    required this.isMine,
    this.commentCount = 0,
    this.caption,
    this.onTime,
    this.image,
  });

  final String id;
  final PostType type;
  final String? caption;
  final List<PostTag> tags;
  final DateTime createdAt;
  final bool? onTime;
  final UserSummary author;
  final List<PetSummary> pets;
  final PostImage? image;
  final ReactionSummary reactions;
  final int commentCount;
  final bool isMine;

  Post copyWith({ReactionSummary? reactions, int? commentCount}) => Post(
        id: id,
        type: type,
        caption: caption,
        tags: tags,
        createdAt: createdAt,
        onTime: onTime,
        author: author,
        pets: pets,
        image: image,
        reactions: reactions ?? this.reactions,
        commentCount: commentCount ?? this.commentCount,
        isMine: isMine,
      );

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        type: PostType.fromApi(json['type'] as String),
        caption: json['caption'] as String?,
        tags: (json['tags'] as List? ?? const []).map((t) => PostTag.fromApi('$t')).whereType<PostTag>().toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        onTime: json['onTime'] as bool?,
        author: UserSummary.fromJson(json['author'] as Map<String, dynamic>),
        pets: (json['pets'] as List? ?? const [])
            .map((p) => PetSummary.fromJson(p as Map<String, dynamic>))
            .toList(),
        image: json['image'] == null ? null : PostImage.fromJson(json['image'] as Map<String, dynamic>),
        reactions: ReactionSummary.fromJson(json['reactions'] as Map<String, dynamic>),
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        isMine: json['isMine'] as bool? ?? false,
      );
}

class PostPage {
  const PostPage({required this.items, this.nextCursor});

  final List<Post> items;
  final String? nextCursor;

  factory PostPage.fromJson(Map<String, dynamic> json) => PostPage(
        items: (json['items'] as List).map((p) => Post.fromJson(p as Map<String, dynamic>)).toList(),
        nextCursor: json['nextCursor'] as String?,
      );
}

class CreatePostResult {
  const CreatePostResult({required this.post, required this.streakCounted, required this.replayed});

  final Post post;
  final bool streakCounted;
  final bool replayed;

  factory CreatePostResult.fromJson(Map<String, dynamic> json) => CreatePostResult(
        post: Post.fromJson(json['post'] as Map<String, dynamic>),
        streakCounted: json['streakCounted'] as bool,
        replayed: json['replayed'] as bool,
      );
}

enum MomentWindowStatus { upcoming, open, late }

class TodayMoment {
  const TodayMoment({
    required this.windowStart,
    required this.windowEnd,
    required this.status,
    required this.participated,
    this.postId,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final MomentWindowStatus status;
  final bool participated;
  final String? postId;

  factory TodayMoment.fromJson(Map<String, dynamic> json) => TodayMoment(
        windowStart: DateTime.parse(json['windowStart'] as String).toLocal(),
        windowEnd: DateTime.parse(json['windowEnd'] as String).toLocal(),
        status: switch (json['status']) {
          'UPCOMING' => MomentWindowStatus.upcoming,
          'OPEN' => MomentWindowStatus.open,
          _ => MomentWindowStatus.late,
        },
        participated: json['participated'] as bool,
        postId: json['postId'] as String?,
      );
}
