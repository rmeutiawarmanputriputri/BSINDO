import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> fetchCurrent();
  Future<void> updateFullName(String fullName);

  /// Hapus akun beserta seluruh data pribadi (RPC `delete_my_account`).
  Future<void> deleteMyAccount();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const PermissionFailure();
    return id;
  }

  @override
  Future<Profile> fetchCurrent() => guardRequest(() async {
        final row = await _client
            .from('profiles')
            .select('id, full_name, role, is_active')
            .eq('id', _uid)
            .single();
        return Profile.fromJson(row);
      });

  @override
  Future<void> updateFullName(String fullName) => guardRequest(() async {
        await _client
            .from('profiles')
            .update({'full_name': fullName.trim()}).eq('id', _uid);
      });

  @override
  Future<void> deleteMyAccount() => guardRequest(() async {
        await _client.rpc('delete_my_account');
      });
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

/// Profil pengguna aktif (nama + role). Dimuat ulang saat pengguna berganti.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchCurrent();
});
