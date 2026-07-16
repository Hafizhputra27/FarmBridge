import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (role != null) {
      state = state.copyWith(isAuthenticated: true, role: role);
    }
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response =
          await Supabase.instance.client.auth.signInAnonymously();
      final userId = response.user!.id;
      state = state.copyWith(isLoading: false, userId: userId);
    } catch (e) {
      debugPrint('signInAnonymously error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> saveProfile({
    required String role,
    required String name,
  }) async {
    final userId = state.userId;
    if (userId == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'User belum sign-in',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await Supabase.instance.client.from('users').insert({
        'id': userId,
        'role': role,
      });

      if (role == 'farmer') {
        await Supabase.instance.client.from('farmer_profiles').insert({
          'user_id': userId,
          'nama': name,
        });
      } else {
        await Supabase.instance.client.from('buyer_profiles').insert({
          'user_id': userId,
          'nama_institusi': name,
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      await prefs.setString('user_name', name);

      state = AuthState(
        isAuthenticated: true,
        role: role,
        userId: userId,
      );
    } catch (e) {
      debugPrint('saveProfile error: $e');
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
