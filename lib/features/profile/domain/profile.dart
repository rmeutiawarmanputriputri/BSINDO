import '../../../core/utils/json.dart';

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.isActive = true,
  });

  factory Profile.fromJson(Json json) => Profile(
    id: reqString(json, 'id'),
    fullName: optString(json, 'full_name') ?? 'Pengguna',
    role: optString(json, 'role') ?? 'user',
    isActive: optBool(json, 'is_active', true),
  );

  final String id;
  final String fullName;

  /// Hanya untuk menampilkan menu admin; keamanan sejati di RLS (D-11).
  final String role;

  /// Akun dinonaktifkan admin (v1.1.0) → konten tidak dapat dibaca (RLS).
  final bool isActive;

  bool get isAdmin => role == 'admin';

  Profile copyWith({String? fullName}) => Profile(
    id: id,
    fullName: fullName ?? this.fullName,
    role: role,
    isActive: isActive,
  );
}
