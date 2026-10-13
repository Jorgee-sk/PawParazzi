import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/providers.dart';
import 'pet_models.dart';

class PetRepository {
  PetRepository(this._api);

  final ApiClient _api;

  Future<List<Pet>> mine() async {
    final list = await _api.get<List<dynamic>>('/api/v1/pets');
    return list.map((p) => Pet.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<Pet> get(String id) async => Pet.fromJson(await _api.get<Map<String, dynamic>>('/api/v1/pets/$id'));

  Future<Pet> create(PetDraft draft) async =>
      Pet.fromJson(await _api.post<Map<String, dynamic>>('/api/v1/pets', data: draft.toJson()));

  Future<Pet> update(String id, PetDraft draft) async =>
      Pet.fromJson(await _api.put<Map<String, dynamic>>('/api/v1/pets/$id', data: draft.toJson()));

  Future<void> delete(String id) => _api.delete<void>('/api/v1/pets/$id');
}

final petRepositoryProvider = Provider<PetRepository>((ref) => PetRepository(ref.watch(apiClientProvider)));

final myPetsProvider = FutureProvider.autoDispose<List<Pet>>((ref) => ref.watch(petRepositoryProvider).mine());

final petProvider = FutureProvider.autoDispose.family<Pet, String>((ref, id) => ref.watch(petRepositoryProvider).get(id));
