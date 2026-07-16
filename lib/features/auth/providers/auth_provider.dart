import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/fcm_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? role;
  final String? userId;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.role,
    this.userId,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? role,
    String? userId,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (role != null && userId != null) {
      state = state.copyWith(isAuthenticated: true, role: role, userId: userId);
    }
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      final userId = response.user!.id;

      final userRow = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      final role = userRow['role'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);

      // User baru login — device token yang didapat FcmService saat app
      // start (sebelum ada session) belum tersimpan, sync sekarang.
      await FcmService().syncDeviceToken();

      state = AuthState(isAuthenticated: true, role: role, userId: userId);
    } on AuthException catch (e) {
      debugPrint('signInWithPassword error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Email atau password salah',
      );
    } catch (e) {
      debugPrint('signInWithPassword error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('user_name');
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).role;
});
