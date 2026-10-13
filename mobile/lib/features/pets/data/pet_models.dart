enum Species {
  dog('DOG', 'Perro'),
  cat('CAT', 'Gato'),
  rabbit('RABBIT', 'Conejo'),
  bird('BIRD', 'Pájaro'),
  rodent('RODENT', 'Roedor'),
  reptile('REPTILE', 'Reptil'),
  other('OTHER', 'Otra especie');

  const Species(this.api, this.label);

  final String api;
  final String label;

  static Species fromApi(String value) => Species.values.firstWhere((s) => s.api == value, orElse: () => other);
}

class Pet {
  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    required this.tags,
    required this.isMine,
    this.breed,
    this.birthDate,
    this.description,
    this.photoMediaId,
    this.photoUrl,
    this.photoThumbnailUrl,
  });

  final String id;
  final String ownerId;
  final String name;
  final Species species;
  final String? breed;
  final DateTime? birthDate;
  final String? description;
  final List<String> tags;
  final String? photoMediaId;
  final String? photoUrl;
  final String? photoThumbnailUrl;
  final bool isMine;

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String,
        name: json['name'] as String,
        species: Species.fromApi(json['species'] as String),
        breed: json['breed'] as String?,
        birthDate: json['birthDate'] == null ? null : DateTime.parse(json['birthDate'] as String),
        description: json['description'] as String?,
        tags: (json['tags'] as List? ?? const []).cast<String>(),
        photoMediaId: json['photoMediaId'] as String?,
        photoUrl: json['photoUrl'] as String?,
        photoThumbnailUrl: json['photoThumbnailUrl'] as String?,
        isMine: json['isMine'] as bool? ?? false,
      );
}

class PetSummary {
  const PetSummary({required this.id, required this.name, required this.species, this.photoUrl});

  final String id;
  final String name;
  final Species species;
  final String? photoUrl;

  factory PetSummary.fromJson(Map<String, dynamic> json) => PetSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        species: Species.fromApi(json['species'] as String),
        photoUrl: json['photoUrl'] as String?,
      );
}

class PetDraft {
  const PetDraft({
    required this.name,
    required this.species,
    this.breed,
    this.description,
    this.tags = const [],
    this.photoMediaId,
  });

  final String name;
  final Species species;
  final String? breed;
  final String? description;
  final List<String> tags;
  final String? photoMediaId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'species': species.api,
        if (breed != null && breed!.isNotEmpty) 'breed': breed,
        if (description != null && description!.isNotEmpty) 'description': description,
        'tags': tags,
        if (photoMediaId != null) 'photoMediaId': photoMediaId,
      };
}
