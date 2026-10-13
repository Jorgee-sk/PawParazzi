class Me {
  const Me({
    required this.id,
    required this.email,
    required this.timeZone,
    required this.profileCompleted,
    required this.petCount,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String timeZone;
  final bool profileCompleted;
  final int petCount;

  bool get hasPets => petCount > 0;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String?,
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        timeZone: json['timeZone'] as String,
        profileCompleted: json['profileCompleted'] as bool,
        petCount: (json['petCount'] as num).toInt(),
      );
}

class UserSummary {
  const UserSummary({required this.id, this.username, this.displayName, this.avatarUrl});

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get name => displayName ?? username ?? 'Alguien';

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        username: json['username'] as String?,
        displayName: json['displayName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

/// Iniciales para el avatar de persona (Figma: "Persona: iniciales o foto").
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  String first(String s) => String.fromCharCode(s.runes.first).toUpperCase();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return first(parts[0]);
  return first(parts[0]) + first(parts[1]);
}
