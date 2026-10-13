import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import '../../profile/data/user_models.dart';

class FriendRequest {
  const FriendRequest({required this.id, required this.requester, required this.addressee, required this.status});

  final String id;
  final UserSummary requester;
  final UserSummary addressee;
  final String status;

  bool get accepted => status == 'ACCEPTED';

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: json['id'] as String,
        requester: UserSummary.fromJson(json['requester'] as Map<String, dynamic>),
        addressee: UserSummary.fromJson(json['addressee'] as Map<String, dynamic>),
        status: json['status'] as String,
      );
}

class FriendsRepository {
  FriendsRepository(this._api);

  final ApiClient _api;

  Future<List<UserSummary>> friends() async {
    final list = await _api.get<List<dynamic>>('/api/v1/friends');
    return list.map((f) => UserSummary.fromJson((f as Map<String, dynamic>)['user'] as Map<String, dynamic>)).toList();
  }

  Future<List<FriendRequest>> requests({required bool incoming}) async {
    final list = await _api.get<List<dynamic>>('/api/v1/friend-requests',
        query: {'direction': incoming ? 'incoming' : 'outgoing'});
    return list.map((r) => FriendRequest.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<FriendRequest> send(String username) async => FriendRequest.fromJson(
      await _api.post<Map<String, dynamic>>('/api/v1/friend-requests', data: {'username': username.trim()}));

  Future<void> accept(String id) => _api.post<dynamic>('/api/v1/friend-requests/$id/accept');

  Future<void> reject(String id) => _api.post<dynamic>('/api/v1/friend-requests/$id/reject');

  Future<void> cancel(String id) => _api.delete<void>('/api/v1/friend-requests/$id');

  Future<void> remove(String userId) => _api.delete<void>('/api/v1/friends/$userId');
}

final friendsRepositoryProvider =
    Provider<FriendsRepository>((ref) => FriendsRepository(ref.watch(apiClientProvider)));

class FriendsOverview {
  const FriendsOverview({required this.friends, required this.incoming, required this.outgoing});

  final List<UserSummary> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
}

final friendsOverviewProvider = FutureProvider.autoDispose<FriendsOverview>((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final results = await Future.wait([
    repo.friends(),
    repo.requests(incoming: true),
    repo.requests(incoming: false),
  ]);
  return FriendsOverview(
    friends: results[0] as List<UserSummary>,
    incoming: results[1] as List<FriendRequest>,
    outgoing: results[2] as List<FriendRequest>,
  );
});
