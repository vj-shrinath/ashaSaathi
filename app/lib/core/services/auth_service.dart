import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> signUp({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': role.value},
    );
    
    if (response.user != null) {
      await _createUserProfile(response.user!.id, role);
    }
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static User? get currentUser => _client.auth.currentUser;

  static UserRole get currentUserRole {
    final user = _client.auth.currentUser;
    if (user == null) return UserRole.asha;
    final roleStr = user.userMetadata?['role'] as String? ?? 'asha';
    return UserRole.fromString(roleStr);
  }

  static String get currentUserId => _client.auth.currentUser?.id ?? '';

  static String get currentUserName {
    final user = _client.auth.currentUser;
    return user?.userMetadata?['full_name'] as String? ?? 
           user?.email?.split('@').first ?? 
           'User';
  }

  static Future<void> _createUserProfile(String userId, UserRole role) async {
    try {
      await _client.from('user_profiles').insert({
        'id': userId,
        'role': role.value,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      });
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST205') rethrow;
    }
  }

  static Future<UserRole?> getUserRole(String userId) async {
    final metadataRole = _client.auth.currentUser?.userMetadata?['role'] as String?;
    if (metadataRole != null && metadataRole.isNotEmpty) {
      return UserRole.fromString(metadataRole);
    }

    try {
      final data = await _client
          .from('user_profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserRole.fromString(data['role'] as String);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        return null;
      }
      rethrow;
    }
  }

  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  static Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      await _client.from('user_profiles').update({
        'role': role.value,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST205') rethrow;
    }
    
    await _client.auth.updateUser(
      UserAttributes(data: {'role': role.value}),
    );
  }
}
